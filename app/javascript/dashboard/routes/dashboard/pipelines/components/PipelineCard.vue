<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  conversation: { type: Object, required: true },
  stages: { type: Array, required: true },
  moving: { type: Boolean, default: false },
});

const emit = defineEmits(['dragStart', 'move', 'open']);
const { t } = useI18n();

const initials = computed(() =>
  props.conversation.contact.name
    .split(/\s+/)
    .slice(0, 2)
    .map(part => part[0])
    .join('')
    .toUpperCase()
);

const elapsed = computed(() => {
  const date = new Date(props.conversation.last_activity_at);
  const minutes = Math.max(
    0,
    Math.floor((Date.now() - date.getTime()) / 60000)
  );
  if (minutes < 60) return t('PIPELINE.TIME.MINUTES', { count: minutes });
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return t('PIPELINE.TIME.HOURS', { count: hours });
  return t('PIPELINE.TIME.DAYS', { count: Math.floor(hours / 24) });
});

const priorityLabel = computed(() => {
  const labels = {
    low: t('PIPELINE.PRIORITY.LOW'),
    medium: t('PIPELINE.PRIORITY.MEDIUM'),
    high: t('PIPELINE.PRIORITY.HIGH'),
    urgent: t('PIPELINE.PRIORITY.URGENT'),
  };
  return labels[props.conversation.priority];
});

const priorityClass = computed(
  () =>
    ({
      urgent: 'bg-ruby-3 text-ruby-11',
      high: 'bg-amber-3 text-amber-11',
      medium: 'bg-blue-3 text-blue-11',
      low: 'bg-n-alpha-2 text-n-slate-11',
    })[props.conversation.priority] || 'bg-n-alpha-2 text-n-slate-11'
);

const onStageChange = event => {
  emit('move', props.conversation, Number(event.target.value));
};
</script>

<template>
  <article
    class="group rounded-xl border border-n-weak bg-n-solid-1 p-3 shadow-sm transition hover:-translate-y-0.5 hover:border-n-strong hover:shadow-md focus-within:border-woot-500"
    :class="{ 'pointer-events-none opacity-60': moving }"
    draggable="true"
    @dragstart="emit('dragStart', conversation, $event)"
  >
    <button
      type="button"
      class="w-full text-left outline-none"
      :aria-label="t('PIPELINE.OPEN_CONVERSATION', { id: conversation.id })"
      @click="emit('open', conversation)"
    >
      <div class="flex items-start gap-2.5">
        <span
          class="flex size-8 shrink-0 items-center justify-center rounded-full bg-woot-100 text-xs font-semibold text-woot-700 dark:bg-woot-900 dark:text-woot-200"
        >
          {{ initials }}
        </span>
        <span class="min-w-0 flex-1">
          <span class="flex items-center justify-between gap-2">
            <span class="truncate text-sm font-medium text-n-slate-12">
              {{ conversation.contact.name }}
            </span>
            <span class="shrink-0 text-xs text-n-slate-10">{{ elapsed }}</span>
          </span>
          <span class="mt-0.5 block text-xs text-n-slate-10">
            {{
              t('PIPELINE.CONVERSATION_META', {
                id: conversation.id,
                inbox: conversation.inbox.name,
              })
            }}
          </span>
        </span>
      </div>

      <p
        v-if="conversation.last_message?.content"
        class="mt-3 line-clamp-2 text-sm leading-5 text-n-slate-11"
      >
        {{ conversation.last_message.content }}
      </p>

      <div class="mt-3 flex flex-wrap items-center gap-1.5">
        <span
          v-if="conversation.priority"
          class="rounded-md px-1.5 py-0.5 text-xs font-medium"
          :class="priorityClass"
        >
          {{ priorityLabel }}
        </span>
        <span
          v-for="label in conversation.labels.slice(0, 2)"
          :key="label"
          class="max-w-32 truncate rounded-md bg-n-alpha-2 px-1.5 py-0.5 text-xs text-n-slate-11"
        >
          {{ label }}
        </span>
      </div>
    </button>

    <div class="mt-3 flex items-center gap-2 border-t border-n-weak pt-2.5">
      <span class="min-w-0 flex-1 truncate text-xs text-n-slate-10">
        {{ conversation.assignee?.name || t('PIPELINE.UNASSIGNED') }}
      </span>
      <label class="sr-only" :for="`stage-${conversation.id}`">
        {{ t('PIPELINE.MOVE_TO') }}
      </label>
      <select
        :id="`stage-${conversation.id}`"
        :value="conversation.pipeline_stage_id"
        class="max-w-36 rounded-md border border-n-weak bg-n-alpha-1 px-2 py-1 text-xs text-n-slate-11 outline-none focus:border-woot-500"
        @change="onStageChange"
      >
        <option v-for="stage in stages" :key="stage.id" :value="stage.id">
          {{ stage.name }}
        </option>
      </select>
    </div>
  </article>
</template>
