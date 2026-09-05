class PipelineStage < ApplicationRecord
  belongs_to :pipeline
  has_many :conversations, dependent: :nullify

  validates :name, presence: true
  validates :position, numericality: { only_integer: true }
end
