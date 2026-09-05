class Pipelines::ConversationPresenter
  class << self
    def render(records)
      conversations = records.to_a
      messages = latest_records(Message.where.not(message_type: :activity), conversations)
      transitions = latest_records(PipelineStageEvent.all, conversations)

      conversations.map do |conversation|
        new(conversation, messages[conversation.id], transitions[conversation.id]).as_json
      end
    end

    private

    def latest_records(scope, conversations)
      scope.where(conversation_id: conversations.map(&:id))
           .select("DISTINCT ON (conversation_id) #{scope.table_name}.*")
           .reorder(:conversation_id, created_at: :desc)
           .index_by(&:conversation_id)
    end
  end

  def initialize(conversation, last_message, transition)
    @conversation = conversation
    @last_message = last_message
    @transition = transition
  end

  def as_json
    {
      id: @conversation.display_id,
      pipeline_stage_id: @conversation.pipeline_stage_id,
      contact: contact_payload,
      inbox: { id: @conversation.inbox.id, name: @conversation.inbox.name },
      assignee: user_payload(@conversation.assignee),
      team: user_payload(@conversation.team),
      status: @conversation.status,
      priority: @conversation.priority,
      labels: @conversation.cached_label_list_array,
      custom_attributes: @conversation.custom_attributes,
      last_message: message_payload,
      last_activity_at: @conversation.last_activity_at.iso8601,
      waiting_since: @conversation.waiting_since&.iso8601,
      transitioned_at: @transition&.created_at&.iso8601
    }
  end

  private

  def contact_payload
    contact = @conversation.contact
    fallback_name = contact.phone_number.presence || "Contato ##{contact.id}"
    { id: contact.id, name: contact.name.presence || fallback_name, phone_number: contact.phone_number }
  end

  def user_payload(record)
    record && { id: record.id, name: record.name }
  end

  def message_payload
    return unless @last_message

    { content: @last_message.content.to_s.truncate(120), created_at: @last_message.created_at.iso8601 }
  end
end
