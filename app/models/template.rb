class Template < ApplicationRecord
  belongs_to :user
  belongs_to :category
  validates :title, presence: true, length: { maximum: 50 }
  #validates :scope, presence: true
  validates :topic, presence: true
  has_many :documents
  has_many :questions, inverse_of: :template, dependent: :destroy
  accepts_nested_attributes_for :questions, allow_destroy: true, reject_if: :all_blank
  #has_many :contains
  #accepts_nested_attributes_for :contains
end
