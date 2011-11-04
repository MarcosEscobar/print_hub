class Print < ApplicationModel
  has_paper_trail
  
  # Constantes
  STATUS = {
    paid: 'P',
    pending_payment: 'X',
    pay_later: 'L'
  }.with_indifferent_access.freeze
  
  # Callbacks
  before_save :mark_order_as_completed, :update_customer_credit, if: :new_record?
  before_save :remove_unnecessary_payments, :mark_as_pending, :print_all_jobs
  before_destroy :can_be_destroyed?

  # Scopes
  scope :pending, where(status: STATUS[:pending_payment])
  scope :pay_later, where(status: STATUS[:pay_later])
  scope :scheduled, where(
    '(printer = :blank OR printer IS NULL) AND scheduled_at IS NOT NULL',
    blank: ''
  )

  # Atributos no persistentes
  attr_accessor :auto_customer_name, :avoid_printing, :include_documents,
    :credit_password, :pay_later

  # Restricciones en los atributos
  attr_readonly :user_id, :customer_id, :printer
  attr_protected :status, :revoked

  # Restricciones
  validates :printer, presence: true, if: ->(p) {
    p.scheduled_at.blank? && !p.print_jobs.reject(&:marked_for_destruction?).empty?
  }
  validates :printer, length: { maximum: 255 }, allow_nil: true,
    allow_blank: true
  validates_datetime :scheduled_at, allow_nil: true, allow_blank: true,
    after: -> { Time.now }
  validates :status, inclusion: { in: STATUS.values }, allow_nil: true,
    allow_blank: true
  validates_each :printer do |record, attr, value|
    printer_changed = !record.printer_was.blank? && record.printer_was != value
    print_and_schedule_new_record = record.new_record? &&
      !record.printer.blank? && !record.scheduled_at.blank?

    if printer_changed || print_and_schedule_new_record
      record.errors.add attr, :must_be_blank
    end
  end
  validates_each :customer_id do |record, attr, value|
    record.errors.add attr, :blank if value.blank? && record.pay_later?
  end
  validate :must_have_one_item, :must_have_valid_payments

  # Relaciones
  belongs_to :user
  belongs_to :customer, autosave: true
  belongs_to :order, autosave: true
  has_many :payments, as: :payable
  has_many :print_jobs, inverse_of: :print
  has_many :article_lines
  autocomplete_for :customer, :name, name: :auto_customer

  accepts_nested_attributes_for :print_jobs, allow_destroy: false,
    reject_if: :reject_print_job_attributes?
  accepts_nested_attributes_for :article_lines, allow_destroy: false,
    reject_if: ->(attributes) { attributes['article_id'].blank? }
  accepts_nested_attributes_for :payments, allow_destroy: false,
    reject_if: ->(attributes) { attributes['amount'].to_f <= 0 }

  def initialize(attributes = nil, options = {})
    super(attributes, options)

    self.user = UserSession.find.try(:user) || self.user rescue self.user
    
    self.pay_later! if self.pay_later == '1' || self.pay_later == true
    self.status ||= STATUS[:pending_payment]
    
    if self.order && self.print_jobs.empty?
      self.customer = self.order.customer
      keys = ['document_id', 'copies', 'range', 'two_sided']
      
      self.order.order_lines.each do |order_line|
        self.print_jobs.build(order_line.attributes.slice(*keys))
      end
    elsif self.include_documents.present?
      self.include_documents.each do |document_id|
        self.print_jobs.build(document_id: document_id)
      end
    end
    
    self.print_jobs.each do |pj|
      pj.price_per_copy = PriceChooser.choose(
        one_sided: !pj.two_sided, copies: self.total_pages
      )
    end

    if self.pay_later?
      self.payments.clear
    else
      self.payment(:cash)
      self.payment(:credit)
    end
  end

  def can_be_destroyed?
    self.article_lines.empty? && self.print_jobs.empty? && self.payments.empty?
  end

  def payment(type)
    self.payments.detect(&:"#{type}?") ||
      self.payments.build(paid_with: Payment::PAID_WITH[type])
  end
  
  def avoid_printing?
    self.avoid_printing == true || self.avoid_printing == '1'
  end

  def print_all_jobs
    if self.printer_was.blank? && !self.printer.blank? && !self.avoid_printing?
      self.print_jobs.reject(&:marked_for_destruction?).each do |pj|
        pj.send_to_print(self.printer, self.user)
      end
    end
  end

  def mark_as_pending
    if self.has_pending_payment?
      self.pending_payment!
    else
      self.paid! if self.pending_payment?
    end

    true
  end
  
  def mark_order_as_completed
    self.order.try(:completed!)
    
    true
  end
  
  def revoke!
    if UserSession.find.try(:record).try(:admin)
      self.revoked = true
      self.payments.each { |p| p.revoked = true }

      if self.customer && self.payments.any?(&:credit?)
        self.customer.add_bonus self.payments.select(&:credit?).sum(&:paid)
      end
      
      self.save validate: false
    end
  end

  def price
    self.print_jobs.reject(&:marked_for_destruction?).to_a.sum(&:price) +
      self.article_lines.reject(&:marked_for_destruction?).to_a.sum(&:price)
  end
  
  def total_pages
    self.print_jobs.reject(&:marked_for_destruction?).sum do |pj|
      pj.copies * pj.range_pages
    end
  end
  
  def reject_print_job_attributes?(attributes)
    has_document = !attributes['document_id'].blank? ||
      !attributes['document'].blank?
    
    !has_document && attributes['pages'].blank?
  end
  
  def must_have_one_item
    print_jobs = self.print_jobs.reject(&:marked_for_destruction?)
    article_lines = self.article_lines.reject(&:marked_for_destruction?)
    
    if print_jobs.empty? && article_lines.empty?
      self.errors.add :base, :must_have_one_item
    end
  end

  def must_have_valid_payments
    if self.pending_payment?
      unless (payment = self.payments.to_a.sum(&:amount)) == self.price
        self.errors.add :payments, :invalid, price: '%.3f' % self.price,
          payment: '%.3f' % payment
      end
    end
  end

  def remove_unnecessary_payments
    credit_payment = self.payments.detect(&:credit?)
    cash_payment = self.payments.detect(&:cash?)

    credit_payment.mark_for_destruction if credit_payment.try(:amount) == 0
    
    if credit_payment && credit_payment.amount > 0 &&
        cash_payment.try(:amount) == 0
      cash_payment.mark_for_destruction
    end
  end

  def update_customer_credit
    if (credit = self.payments.detect(&:credit?)) && credit.amount > 0
      remaining = self.customer.use_credit(
        credit.amount,
        self.credit_password,
        avoid_password_check: self.order.present?
      )

      if remaining == false
        self.errors.add :credit_password, :invalid
        
        false
      elsif remaining > 0
        expected_remaining = self.payments.detect(&:cash?).try(:amount) || 0
        
        raise 'Invalid payment' if remaining != expected_remaining
      end
    end
  end

  def has_pending_payment?
    self.payments.inject(0.0) { |t, p| t + p.amount - p.paid } > 0
  end

  def scheduled?
    self.printer.blank? && !self.scheduled_at.blank?
  end
  
  def status_symbol
    STATUS.invert[self.status]
  end
  
  STATUS.each do |status, value|
    define_method("#{status}?") { self.status == value }
    define_method("#{status}!") { self.status = value }
  end
end