<script setup lang="ts">
import { ref, onMounted } from 'vue';
import axios from 'axios';

interface Post {
  id: number;
  title: string;
  body: string;
}

const posts = ref<Post[]>([]);
const loading = ref(true);
const error = ref<string | null>(null);

onMounted(async () => {
  try {
    const response = await axios.get<Post[]>(
      'https://jsonplaceholder.typicode.com/posts',
      { params: { _limit: 5 } },
    );
    posts.value = response.data;
  } catch (err) {
    error.value = err instanceof Error ? err.message : 'Failed to fetch posts';
  } finally {
    loading.value = false;
  }
});
</script>

<template>
  <div>
    <h2>Dashboard</h2>
    <p>Sample data fetched with Axios:</p>

    <div v-if="loading">Loading...</div>
    <div v-else-if="error" class="error">{{ error }}</div>
    <ul v-else>
      <li v-for="post in posts" :key="post.id">
        <strong>{{ post.title }}</strong>
        <p>{{ post.body }}</p>
      </li>
    </ul>
  </div>
</template>

<style scoped>
.error {
  color: #e53e3e;
  font-weight: 600;
}

li {
  margin-bottom: 1rem;
  padding: 0.75rem;
  border: 1px solid #e2e8f0;
  border-radius: 0.375rem;
}

li strong {
  display: block;
  margin-bottom: 0.25rem;
}
</style>
