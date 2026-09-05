class AddConversationPipelines < ActiveRecord::Migration[7.1]
  def change
    create_pipeline_tables
    add_pipeline_stage_to_conversations
    create_pipeline_stage_events
  end

  private

  def create_pipeline_tables
    create_table :pipelines, if_not_exists: true do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.text :description
      t.integer :position, null: false, default: 0
      t.string :color, default: '#1f93ff'
      t.timestamps
    end

    add_index :pipelines, [:account_id, :name], unique: true, if_not_exists: true
    add_index :pipelines, :position, if_not_exists: true

    create_table :pipeline_stages, if_not_exists: true do |t|
      t.references :pipeline, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.string :color, default: '#1f93ff'
      t.timestamps
    end

    add_index :pipeline_stages, [:pipeline_id, :position], if_not_exists: true
  end

  def add_pipeline_stage_to_conversations
    add_reference :conversations, :pipeline_stage, foreign_key: true, index: true unless column_exists?(:conversations, :pipeline_stage_id)
    add_index :conversations, :pipeline_stage_id, if_not_exists: true
  end

  def create_pipeline_stage_events
    create_table :pipeline_stage_events, if_not_exists: true do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :conversation, null: false, foreign_key: true, index: true
      t.references :from_stage, foreign_key: { to_table: :pipeline_stages }, index: true
      t.references :to_stage, null: false, foreign_key: { to_table: :pipeline_stages }, index: true
      t.references :user, foreign_key: true, index: true
      t.timestamps
    end
  end
end
