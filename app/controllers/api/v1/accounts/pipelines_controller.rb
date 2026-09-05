class Api::V1::Accounts::PipelinesController < Api::V1::Accounts::BaseController
  RESULTS_PER_STAGE = 25
  MAX_RESULTS_PER_STAGE = 50

  before_action :ensure_feature_enabled
  before_action :pipeline
  before_action :check_authorization

  def index
    render json: board_payload
  end

  def stage
    stage = @pipeline.stages.find(params[:stage_id])
    page = [params.fetch(:page, 1).to_i, 1].max
    limit = params.fetch(:limit, RESULTS_PER_STAGE).to_i.clamp(1, MAX_RESULTS_PER_STAGE)
    scope = filtered_conversations.where(pipeline_stage_id: stage.id)
    conversations = scope.order(priority: :desc, last_activity_at: :desc).offset((page - 1) * limit).limit(limit)

    render json: {
      conversations: Pipelines::ConversationPresenter.render(conversations),
      meta: { page: page, limit: limit, total: scope.count }
    }
  end

  def move
    conversation = accessible_conversations.find_by!(display_id: params[:conversation_id])
    authorize conversation, :show?
    stage = @pipeline.stages.find(params.require(:pipeline_stage_id))
    from_stage = conversation.pipeline_stage

    ActiveRecord::Base.transaction do
      conversation.update!(pipeline_stage: stage)
      PipelineStageEvent.create!(
        account: Current.account,
        conversation: conversation,
        from_stage: from_stage,
        to_stage: stage,
        user: Current.user
      )
    end

    render json: { conversation: Pipelines::ConversationPresenter.render([conversation.reload]).first }
  end

  private

  def check_authorization
    authorize @pipeline, action_name == 'move' ? :update? : :show?
  end

  def ensure_feature_enabled
    return if Current.account.feature_enabled?('pipelines')

    head :not_found
  end

  def pipeline
    pipeline_id = params[:pipeline_id].presence || params[:id].presence
    @pipeline = if pipeline_id.present?
                  Current.account.pipelines.find(pipeline_id)
                else
                  Current.account.pipelines.order(:position, :id).first!
                end
  end

  def board_payload
    scope = filtered_conversations
    counts = scope.group(:pipeline_stage_id).count
    limit = params.fetch(:limit, RESULTS_PER_STAGE).to_i.clamp(1, MAX_RESULTS_PER_STAGE)

    {
      pipeline: serialize_pipeline(@pipeline),
      pipelines: available_pipelines,
      stages: stage_payloads(scope, counts, limit),
      metrics: metrics(scope),
      filters: filter_options
    }
  end

  def available_pipelines
    Current.account.pipelines.order(:position, :id).map do |record|
      serialize_pipeline(record, include_stages: false)
    end
  end

  def stage_payloads(scope, counts, limit)
    @pipeline.stages.map do |stage|
      conversations = stage_conversations(scope, stage, limit)
      serialize_stage(stage, counts.fetch(stage.id, 0), conversations)
    end
  end

  def stage_conversations(scope, stage, limit)
    scope.where(pipeline_stage_id: stage.id)
         .order(priority: :desc, last_activity_at: :desc)
         .limit(limit)
  end

  def serialize_stage(stage, total, conversations)
    {
      id: stage.id,
      name: stage.name,
      color: stage.color,
      position: stage.position,
      total: total,
      conversations: Pipelines::ConversationPresenter.render(conversations)
    }
  end

  def serialize_pipeline(record, include_stages: true)
    payload = {
      id: record.id,
      name: record.name,
      description: record.description,
      color: record.color,
      position: record.position
    }
    payload[:stage_ids] = record.stages.map(&:id) if include_stages
    payload
  end

  def filtered_conversations
    scope = accessible_conversations.where(pipeline_stage_id: @pipeline.stages.select(:id))
    scope = filter_by_search(scope)
    scope = apply_standard_filters(scope)
    filter_by_assignee(scope)
  end

  def filter_by_search(scope)
    return scope if params[:search].blank?

    term = params[:search].to_s.strip
    scope.joins(:contact).where(
      'contacts.name ILIKE :term OR contacts.phone_number ILIKE :term OR CAST(conversations.display_id AS TEXT) = :exact',
      term: "%#{ActiveRecord::Base.sanitize_sql_like(term)}%",
      exact: term
    )
  end

  def apply_standard_filters(scope)
    scope = scope.where(inbox_id: params[:inbox_id]) if params[:inbox_id].present?
    scope = scope.where(status: params[:status]) if Conversation.statuses.key?(params[:status])
    scope = scope.where(priority: params[:priority]) if Conversation.priorities.key?(params[:priority])
    scope
  end

  def filter_by_assignee(scope)
    return scope if params[:assignee_id].blank?
    return scope.where(assignee_id: nil) if params[:assignee_id] == 'unassigned'

    scope.where(assignee_id: params[:assignee_id])
  end

  def accessible_conversations
    scope = Current.account.conversations.includes(:contact, :inbox, :assignee, :team, :pipeline_stage)
    return scope if Current.account_user.administrator?

    inbox_scope = scope.where(inbox_id: Current.user.inboxes.where(account_id: Current.account.id).select(:id))
    team_scope = scope.where(team_id: Current.user.teams.where(account_id: Current.account.id).select(:id))
    inbox_scope.or(team_scope)
  end

  def metrics(scope)
    {
      total: scope.count,
      urgent: scope.where(priority: :urgent).count,
      unassigned: scope.where(assignee_id: nil).count,
      waiting_documents: scope.joins(:pipeline_stage).where(pipeline_stages: { name: 'Aguardando laudo' }).count,
      clients: scope.joins(:pipeline_stage).where(pipeline_stages: { name: 'Cliente' }).count
    }
  end

  def filter_options
    inboxes = if Current.account_user.administrator?
                Current.account.inboxes
              else
                Current.user.inboxes.where(account_id: Current.account.id)
              end
    {
      inboxes: inboxes.order(:name).map { |inbox| { id: inbox.id, name: inbox.name } },
      agents: Current.account.users.order(:name).map { |user| { id: user.id, name: user.name } },
      statuses: Conversation.statuses.keys,
      priorities: Conversation.priorities.keys
    }
  end
end
