<script setup lang="ts">
import { RouterLink, RouterView } from 'vue-router';
</script>

<template>
  <div id="layout">
    <header>
      <h1>Vue + Vite Test App</h1>
      <nav>
        <RouterLink to="/">Home</RouterLink>
        <RouterLink to="/about">About</RouterLink>
        <RouterLink to="/dashboard">Dashboard</RouterLink>
      </nav>
    </header>

    <main>
      <RouterView />
    </main>
  </div>
</template>

<style scoped>
#layout {
  max-width: 800px;
  margin: 0 auto;
  padding: 2rem;
  font-family: system-ui, -apple-system, sans-serif;
}

header {
  margin-bottom: 2rem;
}

nav {
  display: flex;
  gap: 1rem;
  margin-top: 0.5rem;
}

nav a {
  color: #42b883;
  text-decoration: none;
  font-weight: 500;
}

nav a:hover {
  text-decoration: underline;
}
</style>
