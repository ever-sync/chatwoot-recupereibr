# frozen_string_literal: true

FactoryBot.define do
  factory :pipeline do
    account
    sequence(:name) { |number| "Pipeline #{number}" }
    position { 0 }
    color { '#1f93ff' }
  end

  factory :pipeline_stage do
    pipeline
    sequence(:name) { |number| "Stage #{number}" }
    position { 0 }
    color { '#1f93ff' }
  end

  factory :pipeline_stage_event do
    account
    conversation
    association :to_stage, factory: :pipeline_stage
  end
end
