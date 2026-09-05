import { frontendURL } from 'dashboard/helper/URLHelper';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

const PipelineBoard = () => import('./PipelineBoard.vue');

export const routes = [
  {
    path: frontendURL('accounts/:accountId/pipelines'),
    name: 'pipeline_board',
    component: PipelineBoard,
    meta: {
      featureFlag: FEATURE_FLAGS.PIPELINES,
      permissions: [
        'administrator',
        'agent',
        'conversation_manage',
        'conversation_unassigned_manage',
      ],
    },
  },
];
