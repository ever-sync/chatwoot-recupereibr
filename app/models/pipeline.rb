class Pipeline < ApplicationRecord
  belongs_to :account
  has_many :stages, -> { order(:position, :id) },
           class_name: 'PipelineStage', dependent: :destroy, inverse_of: :pipeline

  validates :name, presence: true, uniqueness: { scope: :account_id }
  validates :position, numericality: { only_integer: true }
end
