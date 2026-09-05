class PipelineStageEvent < ApplicationRecord
  belongs_to :account
  belongs_to :conversation
  belongs_to :from_stage, class_name: 'PipelineStage', optional: true
  belongs_to :to_stage, class_name: 'PipelineStage'
  belongs_to :user, optional: true
end
