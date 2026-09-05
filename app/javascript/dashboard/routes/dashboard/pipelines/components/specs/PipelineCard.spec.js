import { mount } from '@vue/test-utils';
import PipelineCard from '../PipelineCard.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, values = {}) => {
      const messages = {
        'PIPELINE.CONVERSATION_META': '#{id} · {inbox}',
        'PIPELINE.PRIORITY.URGENT': 'Urgente',
      };
      return Object.entries(values).reduce(
        (label, [name, value]) => label.replace(`{${name}}`, value),
        messages[key] || key
      );
    },
  }),
}));

const stages = [
  { id: 1, name: 'Novo lead' },
  { id: 2, name: 'Em análise' },
];

const conversation = {
  id: 42,
  pipeline_stage_id: 1,
  contact: { name: 'Maria Silva', phone_number: '+5512999999999' },
  inbox: { id: 5, name: 'WhatsApp Davi' },
  assignee: { id: 3, name: 'Jorge' },
  priority: 'urgent',
  labels: ['laudo-recebido'],
  last_message: { content: 'Enviei meu laudo agora.' },
  last_activity_at: new Date().toISOString(),
};

const mountCard = () =>
  mount(PipelineCard, {
    props: { conversation, stages },
  });

describe('PipelineCard', () => {
  it('renders the operational conversation summary', () => {
    const wrapper = mountCard();

    expect(wrapper.text()).toContain('Maria Silva');
    expect(wrapper.text()).toContain('WhatsApp Davi');
    expect(wrapper.text()).toContain('Enviei meu laudo agora.');
    expect(wrapper.text()).toContain('Jorge');
    expect(wrapper.text()).toContain('laudo-recebido');
  });

  it('opens the conversation from the card', async () => {
    const wrapper = mountCard();

    await wrapper.get('button').trigger('click');

    expect(wrapper.emitted('open')).toEqual([[conversation]]);
  });

  it('emits a numeric target stage when the selector changes', async () => {
    const wrapper = mountCard();

    await wrapper.get('select').setValue('2');

    expect(wrapper.emitted('move')).toEqual([[conversation, 2]]);
  });
});
