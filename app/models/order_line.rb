class OrderLine < ApplicationModel
  has_paper_trail
  
  # Atributos "permitidos"
  attr_accessible :document_id, :copies, :order_id, :lock_version,
    :print_job_type_id
  
  # Restricciones
  validates :copies, :price_per_copy, presence: true
  validates :copies, allow_nil: true, allow_blank: true,
    numericality: { only_integer: true, greater_than: 0, less_than: 2147483648 }
  validates :price_per_copy, numericality: {greater_than_or_equal_to: 0},
    allow_nil: true, allow_blank: true
  
  # Relaciones
  belongs_to :document
  belongs_to :order
  belongs_to :print_job_type
  
  def initialize(attributes = nil, options = {})
    super(attributes, options)

    self.print_job_type ||= PrintJobType.default
    self.copies ||= 1
    self.price_per_copy ||= job_price_per_copy
  end
  
  def price
    total_pages * job_price_per_copy
  end

  def total_pages
    (self.document.try(:pages) || 0) * (self.copies || 0)
  end

  def job_price_per_copy
    PriceChooser.choose(
      type: self.print_job_type,
      copies: self.order.try(:total_pages_by_type, self.print_job_type)
    )
  end
end
