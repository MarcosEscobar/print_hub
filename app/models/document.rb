class Document < ActiveRecord::Base
  has_attached_file :file

  # Restricciones
  validates :name, :code, :presence => true
  validates :code, :uniqueness => true, :allow_nil => true, :allow_blank => true
  validates :name, :code, :length => { :maximum => 255 }, :allow_nil => true,
    :allow_blank => true
  validates_attachment_content_type :file, :content_type => /pdf/i,
    :allow_nil => true, :allow_blank => true
end