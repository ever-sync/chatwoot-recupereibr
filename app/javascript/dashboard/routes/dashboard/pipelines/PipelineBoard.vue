<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import PipelinesAPI from 'dashboard/api/pipelines';
import PipelineColumn from './components/PipelineColumn.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const board = ref(null);
const loading = ref(true);
const movingId = ref(null);
const loadingStages = ref(new Set());
const search = ref(route.query.search || '');
const pipelineId = ref(Number(route.query.pipeline_id) || null);
const inboxId = ref(Number(route.query.inbox_id) || null);
const assigneeId = ref(route.query.assignee_id || null);
const priority = ref(route.query.priority || null);
const status = ref(route.query.status || null);
let searchTimer;

const stages = computed(() => board.value?.stages || []);
const filters = computed(
  () => board.value?.filters || { inboxes: [], agents: [] }
);
const metrics = computed(() => board.value?.metrics || {});
const priorityLabels = computed(() => ({
  low: t('PIPELINE.PRIORITY.LOW'),
  medium: t('PIPELINE.PRIORITY.MEDIUM'),
  high: t('PIPELINE.PRIORITY.HIGH'),
  urgent: t('PIPELINE.PRIORITY.URGENT'),
}));
const statusLabels = computed(() => ({
  open: t('PIPELINE.STATUS.OPEN'),
  resolved: t('PIPELINE.STATUS.RESOLVED'),
  pending: t('PIPELINE.STATUS.PENDING'),
  snoozed: t('PIPELINE.STATUS.SNOOZED'),
}));

const requestParams = () => ({
  ...(pipelineId.value && { pipeline_id: pipelineId.value }),
  ...(search.value.trim() && { search: search.value.trim() }),
  ...(inboxId.value && { inbox_id: inboxId.value }),
  ...(assigneeId.value && { assignee_id: assigneeId.value }),
  ...(priority.value && { priority: priority.value }),
  ...(status.value && { status: status.value }),
});

const syncUrl = () => {
  router.replace({ query: requestParams() });
};

const fetchBoard = async ({ quiet = false } = {}) => {
  if (!quiet) loading.value = true;
  try {
    const { data } = await PipelinesAPI.getBoard(requestParams());
    board.value = data;
    if (!pipelineId.value) pipelineId.value = data.pipeline.id;
    syncUrl();
  } catch (error) {
    useAlert(error.response?.data?.message || t('PIPELINE.ERRORS.LOAD'));
  } finally {
    loading.value = false;
  }
};

const resetFilters = () => {
  search.value = '';
  inboxId.value = null;
  assigneeId.value = null;
  priority.value = null;
  status.value = null;
};

const findCard = conversationId => {
  return stages.value.reduce((result, stage) => {
    if (result) return result;
    const index = stage.conversations.findIndex(
      card => card.id === conversationId
    );
    return index >= 0
      ? { stage, index, card: stage.conversations[index] }
      : null;
  }, null);
};

const moveCard = async (conversation, targetStageId) => {
  if (conversation.pipeline_stage_id === targetStageId || movingId.value)
    return;
  const source = findCard(conversation.id);
  const target = stages.value.find(stage => stage.id === targetStageId);
  if (!source || !target) return;

  const previousStageId = source.stage.id;
  source.stage.conversations.splice(source.index, 1);
  source.stage.total -= 1;
  conversation.pipeline_stage_id = targetStageId;
  target.conversations.unshift(conversation);
  target.total += 1;
  movingId.value = conversation.id;

  try {
    await PipelinesAPI.moveConversation(
      board.value.pipeline.id,
      conversation.id,
      targetStageId
    );
    useAlert(t('PIPELINE.MOVE_SUCCESS', { stage: target.name }));
    await fetchBoard({ quiet: true });
  } catch (error) {
    target.conversations = target.conversations.filter(
      card => card.id !== conversation.id
    );
    target.total -= 1;
    conversation.pipeline_stage_id = previousStageId;
    source.stage.conversations.splice(source.index, 0, conversation);
    source.stage.total += 1;
    useAlert(error.response?.data?.message || t('PIPELINE.ERRORS.MOVE'));
  } finally {
    movingId.value = null;
  }
};

const onDragStart = (conversation, event) => {
  event.dataTransfer.effectAllowed = 'move';
  event.dataTransfer.setData('text/plain', String(conversation.id));
};

const onDrop = (stage, event) => {
  const conversationId = Number(event.dataTransfer.getData('text/plain'));
  const source = findCard(conversationId);
  if (source) moveCard(source.card, stage.id);
};

const loadMore = async stage => {
  if (loadingStages.value.has(stage.id)) return;
  loadingStages.value = new Set([...loadingStages.value, stage.id]);
  const page = Math.floor(stage.conversations.length / 25) + 1;
  try {
    const { data } = await PipelinesAPI.getStage(
      board.value.pipeline.id,
      stage.id,
      {
        ...requestParams(),
        page,
      }
    );
    const known = new Set(stage.conversations.map(card => card.id));
    stage.conversations.push(
      ...data.conversations.filter(card => !known.has(card.id))
    );
    stage.total = data.meta.total;
  } catch (error) {
    useAlert(error.response?.data?.message || t('PIPELINE.ERRORS.LOAD_MORE'));
  } finally {
    const next = new Set(loadingStages.value);
    next.delete(stage.id);
    loadingStages.value = next;
  }
};

const openConversation = conversation => {
  router.push({
    name: 'inbox_conversation',
    params: {
      accountId: route.params.accountId,
      conversation_id: conversation.id,
    },
  });
};

watch([inboxId, assigneeId, priority, status], () => fetchBoard());
watch(search, () => {
  window.clearTimeout(searchTimer);
  searchTimer = window.setTimeout(() => fetchBoard(), 350);
});

onMounted(() => fetchBoard());
onBeforeUnmount(() => window.clearTimeout(searchTimer));
</script>

<template>
  <section
    class="flex h-full min-w-0 flex-1 flex-col overflow-hidden bg-n-surface-1"
  >
    <header class="shrink-0 border-b border-n-weak bg-n-solid-1 px-6 py-4">
      <div class="flex flex-wrap items-start justify-between gap-4">
        <div>
          <div class="flex items-center gap-2">
            <span class="i-lucide-kanban size-5 text-woot-600" />
            <h1 class="text-xl font-semibold text-n-slate-12">
              {{ t('PIPELINE.TITLE') }}
            </h1>
          </div>
          <p class="mt-1 text-sm text-n-slate-10">
            {{ board?.pipeline?.name || t('PIPELINE.LOADING') }}
          </p>
        </div>

        <button
          type="button"
          class="flex h-9 items-center gap-2 rounded-lg border border-n-weak px-3 text-sm font-medium text-n-slate-11 transition hover:bg-n-alpha-2"
          :disabled="loading"
          @click="fetchBoard()"
        >
          <span
            class="i-lucide-refresh-cw size-4"
            :class="{ 'animate-spin': loading }"
          />
          {{ t('PIPELINE.REFRESH') }}
        </button>
      </div>

      <div v-if="board" class="mt-4 grid grid-cols-2 gap-2 md:grid-cols-5">
        <div class="rounded-xl bg-n-alpha-1 px-3 py-2">
          <span class="block text-xs text-n-slate-10">{{
            t('PIPELINE.METRICS.TOTAL')
          }}</span>
          <strong class="text-lg text-n-slate-12">{{ metrics.total }}</strong>
        </div>
        <div class="rounded-xl bg-ruby-3 px-3 py-2">
          <span class="block text-xs text-ruby-10">{{
            t('PIPELINE.METRICS.URGENT')
          }}</span>
          <strong class="text-lg text-ruby-11">{{ metrics.urgent }}</strong>
        </div>
        <div class="rounded-xl bg-amber-3 px-3 py-2">
          <span class="block text-xs text-amber-10">{{
            t('PIPELINE.METRICS.UNASSIGNED')
          }}</span>
          <strong class="text-lg text-amber-11">{{
            metrics.unassigned
          }}</strong>
        </div>
        <div class="rounded-xl bg-blue-3 px-3 py-2">
          <span class="block text-xs text-blue-10">{{
            t('PIPELINE.METRICS.DOCUMENTS')
          }}</span>
          <strong class="text-lg text-blue-11">{{
            metrics.waiting_documents
          }}</strong>
        </div>
        <div class="rounded-xl bg-grass-3 px-3 py-2">
          <span class="block text-xs text-grass-10">{{
            t('PIPELINE.METRICS.CLIENTS')
          }}</span>
          <strong class="text-lg text-grass-11">{{ metrics.clients }}</strong>
        </div>
      </div>

      <div class="mt-4 flex flex-wrap items-center gap-2">
        <label class="relative min-w-56 flex-1 md:max-w-80">
          <span class="sr-only">{{ t('PIPELINE.FILTERS.SEARCH') }}</span>
          <span
            class="i-lucide-search absolute left-3 top-2.5 size-4 text-n-slate-9"
          />
          <input
            v-model="search"
            type="search"
            class="h-9 w-full rounded-lg border border-n-weak bg-n-alpha-1 pl-9 pr-3 text-sm text-n-slate-12 outline-none placeholder:text-n-slate-9 focus:border-woot-500"
            :placeholder="t('PIPELINE.FILTERS.SEARCH_PLACEHOLDER')"
          />
        </label>

        <select
          v-model="pipelineId"
          :aria-label="t('PIPELINE.FILTERS.PIPELINE')"
          class="h-9 rounded-lg border border-n-weak bg-n-alpha-1 px-3 text-sm text-n-slate-11 outline-none focus:border-woot-500"
          @change="fetchBoard()"
        >
          <option
            v-for="pipeline in board?.pipelines || []"
            :key="pipeline.id"
            :value="pipeline.id"
          >
            {{ pipeline.name }}
          </option>
        </select>
        <select
          v-model="inboxId"
          :aria-label="t('PIPELINE.FILTERS.INBOX')"
          class="h-9 rounded-lg border border-n-weak bg-n-alpha-1 px-3 text-sm text-n-slate-11 outline-none focus:border-woot-500"
        >
          <option :value="null">{{ t('PIPELINE.FILTERS.ALL_INBOXES') }}</option>
          <option
            v-for="inbox in filters.inboxes"
            :key="inbox.id"
            :value="inbox.id"
          >
            {{ inbox.name }}
          </option>
        </select>
        <select
          v-model="assigneeId"
          :aria-label="t('PIPELINE.FILTERS.ASSIGNEE')"
          class="h-9 rounded-lg border border-n-weak bg-n-alpha-1 px-3 text-sm text-n-slate-11 outline-none focus:border-woot-500"
        >
          <option :value="null">{{ t('PIPELINE.FILTERS.ALL_AGENTS') }}</option>
          <option value="unassigned">{{ t('PIPELINE.UNASSIGNED') }}</option>
          <option
            v-for="agent in filters.agents"
            :key="agent.id"
            :value="agent.id"
          >
            {{ agent.name }}
          </option>
        </select>
        <select
          v-model="priority"
          :aria-label="t('PIPELINE.FILTERS.PRIORITY')"
          class="h-9 rounded-lg border border-n-weak bg-n-alpha-1 px-3 text-sm text-n-slate-11 outline-none focus:border-woot-500"
        >
          <option :value="null">
            {{ t('PIPELINE.FILTERS.ALL_PRIORITIES') }}
          </option>
          <option v-for="item in filters.priorities" :key="item" :value="item">
            {{ priorityLabels[item] || item }}
          </option>
        </select>
        <select
          v-model="status"
          :aria-label="t('PIPELINE.FILTERS.STATUS')"
          class="h-9 rounded-lg border border-n-weak bg-n-alpha-1 px-3 text-sm text-n-slate-11 outline-none focus:border-woot-500"
        >
          <option :value="null">
            {{ t('PIPELINE.FILTERS.ALL_STATUSES') }}
          </option>
          <option v-for="item in filters.statuses" :key="item" :value="item">
            {{ statusLabels[item] || item }}
          </option>
        </select>
        <button
          v-if="search || inboxId || assigneeId || priority || status"
          type="button"
          class="h-9 rounded-lg px-3 text-sm font-medium text-woot-600 hover:bg-woot-50 dark:hover:bg-woot-950/30"
          @click="resetFilters"
        >
          {{ t('PIPELINE.FILTERS.CLEAR') }}
        </button>
      </div>
    </header>

    <div
      v-if="loading && !board"
      class="flex flex-1 items-center justify-center"
    >
      <span class="i-lucide-loader-circle size-7 animate-spin text-woot-600" />
    </div>

    <main v-else class="flex-1 overflow-x-auto overflow-y-hidden p-4">
      <div class="flex h-full min-w-max gap-3">
        <PipelineColumn
          v-for="stage in stages"
          :key="stage.id"
          :stage="stage"
          :stages="stages"
          :moving-id="movingId"
          :loading-more="loadingStages.has(stage.id)"
          @drag-start="onDragStart"
          @drop="event => onDrop(stage, event)"
          @move="moveCard"
          @open="openConversation"
          @load-more="loadMore(stage)"
        />
      </div>
    </main>
  </section>
</template>
