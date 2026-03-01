<script setup lang="ts">
import { useCounterStore } from '../stores/counter';

const counter = useCounterStore();
</script>

<template>
  <div class="counter-widget">
    <h3>Pinia Counter</h3>
    <p>Count: <strong>{{ counter.count }}</strong></p>
    <p>Double: <strong>{{ counter.doubleCount }}</strong></p>
    <div class="actions">
      <button @click="counter.decrement">-</button>
      <button @click="counter.reset">Reset</button>
      <button @click="counter.increment">+</button>
    </div>
  </div>
</template>

<style scoped>
.counter-widget {
  margin-top: 1.5rem;
  padding: 1rem;
  border: 1px solid #e2e8f0;
  border-radius: 0.5rem;
}

.actions {
  display: flex;
  gap: 0.5rem;
  margin-top: 0.75rem;
}

button {
  padding: 0.375rem 0.75rem;
  border: 1px solid #cbd5e1;
  border-radius: 0.25rem;
  background: white;
  cursor: pointer;
  font-size: 0.875rem;
}

button:hover {
  background: #f1f5f9;
}
</style>
