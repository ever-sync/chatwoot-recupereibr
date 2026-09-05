require 'rails_helper'

RSpec.describe 'Conversation Pipelines API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let!(:pipeline) { create(:pipeline, account: account, name: 'Atendimento') }
  let!(:new_stage) { create(:pipeline_stage, pipeline: pipeline, name: 'Novo lead', position: 0) }
  let!(:analysis_stage) { create(:pipeline_stage, pipeline: pipeline, name: 'Em análise', position: 1) }
  let!(:conversation) do
    create(:conversation, account: account, pipeline_stage: new_stage, priority: :urgent).tap do |record|
      create(:message, account: account, inbox: record.inbox, conversation: record, content: 'Preciso de ajuda')
    end
  end

  before do
    account.enable_features!('pipelines')
  end

  describe 'GET /api/v1/accounts/:account_id/pipelines' do
    it 'returns the board, metrics, filters, and cards' do
      get "/api/v1/accounts/#{account.id}/pipelines",
          headers: admin.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('pipeline', 'id')).to eq(pipeline.id)
      expect(response.parsed_body['stages'].pluck('name')).to eq(['Novo lead', 'Em análise'])
      expect(response.parsed_body.dig('metrics', 'total')).to eq(1)
      expect(response.parsed_body.dig('metrics', 'urgent')).to eq(1)
      expect(response.parsed_body.dig('stages', 0, 'conversations', 0, 'id')).to eq(conversation.display_id)
      expect(response.parsed_body.dig('stages', 0, 'conversations', 0, 'last_message', 'content')).to eq('Preciso de ajuda')
    end

    it 'returns unauthorized without a session' do
      get "/api/v1/accounts/#{account.id}/pipelines", as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'does not expose the endpoint when the account feature is disabled' do
      account.disable_features!('pipelines')

      get "/api/v1/accounts/#{account.id}/pipelines",
          headers: admin.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'only returns conversations from inboxes an agent can access' do
      agent = create(:user, account: account, role: :agent)
      create(:inbox_member, inbox: conversation.inbox, user: agent)
      hidden_conversation = create(:conversation, account: account, pipeline_stage: new_stage)

      get "/api/v1/accounts/#{account.id}/pipelines",
          headers: agent.create_new_auth_token,
          as: :json

      card_ids = response.parsed_body['stages'].flat_map { |stage| stage['conversations'].pluck('id') }
      expect(response).to have_http_status(:ok)
      expect(card_ids).to include(conversation.display_id)
      expect(card_ids).not_to include(hidden_conversation.display_id)
    end

    it 'filters cards by contact search' do
      conversation.contact.update!(name: 'Maria Kanban')

      get "/api/v1/accounts/#{account.id}/pipelines",
          params: { search: 'Maria Kanban' },
          headers: admin.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('metrics', 'total')).to eq(1)
    end
  end

  describe 'GET /api/v1/accounts/:account_id/pipelines/:id/stages/:stage_id' do
    it 'paginates a stage using the requested pipeline' do
      create(:pipeline, account: account, position: -1)

      get "/api/v1/accounts/#{account.id}/pipelines/#{pipeline.id}/stages/#{new_stage.id}",
          params: { limit: 1 },
          headers: admin.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['conversations'].length).to eq(1)
      expect(response.parsed_body.dig('meta', 'total')).to eq(1)
    end
  end

  describe 'PATCH /api/v1/accounts/:account_id/pipelines/:id/conversations/:conversation_id' do
    it 'moves a card and records who moved it' do
      expect do
        patch "/api/v1/accounts/#{account.id}/pipelines/#{pipeline.id}/conversations/#{conversation.display_id}",
              params: { pipeline_stage_id: analysis_stage.id },
              headers: admin.create_new_auth_token,
              as: :json
      end.to change(PipelineStageEvent, :count).by(1)

      event = PipelineStageEvent.last
      expect(response).to have_http_status(:ok)
      expect(conversation.reload.pipeline_stage).to eq(analysis_stage)
      expect(event).to have_attributes(
        account_id: account.id,
        conversation_id: conversation.id,
        from_stage_id: new_stage.id,
        to_stage_id: analysis_stage.id,
        user_id: admin.id
      )
    end

    it 'rejects a stage from another account' do
      other_stage = create(:pipeline_stage, pipeline: create(:pipeline))

      patch "/api/v1/accounts/#{account.id}/pipelines/#{pipeline.id}/conversations/#{conversation.display_id}",
            params: { pipeline_stage_id: other_stage.id },
            headers: admin.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:not_found)
      expect(conversation.reload.pipeline_stage).to eq(new_stage)
    end
  end
end
