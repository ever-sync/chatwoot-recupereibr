/* global axios */
import ApiClient from './ApiClient';

class PipelinesAPI extends ApiClient {
  constructor() {
    super('pipelines', { accountScoped: true });
  }

  getBoard(params = {}) {
    return axios.get(this.url, { params });
  }

  getStage(pipelineId, stageId, params = {}) {
    return axios.get(`${this.url}/${pipelineId}/stages/${stageId}`, { params });
  }

  moveConversation(pipelineId, conversationId, pipelineStageId) {
    return axios.patch(
      `${this.url}/${pipelineId}/conversations/${conversationId}`,
      { pipeline_stage_id: pipelineStageId }
    );
  }
}

export default new PipelinesAPI();
