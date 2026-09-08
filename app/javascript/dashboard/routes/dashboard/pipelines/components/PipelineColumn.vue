<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import PipelineCard from './PipelineCard.vue';

defineProps({
  stage: { type: Object, required: true },
  stages: { type: Array, required: true },
  movingId: { type: Number, default: null },
  loadingMore: { type: Boolean, default: false },
});

const emit = defineEmits(['drop', 'dragStart', 'move', 'open', 'loadMore']);
const { t } = useI18n();
const isOver = ref(false);

const handleDrop = event => {
  isOver.value = false;
  emit('drop', event);
};
</script>

<template>
  <section
    class="flex h-full min-h-0 w-[21rem] shrink-0 flex-col rounded-2xl border border-n-weak bg-n-alpha-1 transition"
    :class="{ 'border-woot-500 bg-woot-50/40 dark:bg-woot-950/20': isOver }"
    @dragover.prevent="isOver = true"
    @dragleave.self="isOver = false"
    @drop.prevent="handleDrop"
  >
    <header class="flex items-center justify-between gap-3 px-3.5 py-3">
      <div class="flex min-w-0 items-center gap-2">
        <span
          class="size-2.5 shrink-0 rounded-full"
          :style="{ backgroundColor: stage.color || '#1f93ff' }"
        />
        <h2 class="truncate text-sm font-semibold text-n-slate-12">
          {{ stage.name }}
        </h2>
      </div>
      <span
        class="rounded-full bg-n-alpha-2 px-2 py-0.5 text-xs font-medium text-n-slate-11"
      >
        {{ stage.total }}
      </span>
    </header>

    <div class="min-h-0 flex-1 space-y-2.5 overflow-y-auto px-2.5 pb-3">
      <PipelineCard
        v-for="conversation in stage.conversations"
        :key="conversation.id"
        :conversation="conversation"
        :stages="stages"
        :moving="movingId === conversation.id"
        @drag-start="(card, event) => emit('dragStart', card, event)"
        @move="(card, stageId) => emit('move', card, stageId)"
        @open="card => emit('open', card)"
      />

      <div
        v-if="!stage.conversations.length"
        class="flex min-h-28 flex-col items-center justify-center rounded-xl border border-dashed border-n-weak px-4 text-center"
      >
        <span class="i-lucide-inbox mb-2 size-5 text-n-slate-9" />
        <p class="text-xs text-n-slate-10">{{ t('PIPELINE.EMPTY_STAGE') }}</p>
      </div>

      <button
        v-if="stage.conversations.length < stage.total"
        type="button"
        class="w-full rounded-lg border border-n-weak px-3 py-2 text-xs font-medium text-n-slate-11 transition hover:bg-n-alpha-2 disabled:opacity-60"
        :disabled="loadingMore"
        @click="emit('loadMore')"
      >
        {{ loadingMore ? t('PIPELINE.LOADING') : t('PIPELINE.LOAD_MORE') }}
      </button>
    </div>
  </section>
</template>
