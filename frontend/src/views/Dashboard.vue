<template>
  <div class="dashboard">
    <h1>Доступні підключення</h1>

    <div v-if="Object.keys(connections).length === 0" class="empty-message">
      🙁 Поки що немає доступних підключень
    </div>

    <div v-else class="grid">
      <ConnectionCard
        v-for="(conn, id) in connections"
        :key="id"
        :conn="conn"
        :id="id"
      />
    </div>
  </div>
</template>

<script setup>
import { onMounted, ref } from 'vue'
import ConnectionCard from '../components/ConnectionCard.vue'

const token = ref(null)
const connections = ref({})

onMounted(async () => {
  token.value = sessionStorage.getItem("guac_token")
  if (!token.value) {
    window.location.href = "/login"
    return
  }
  try {
    const res = await fetch(`/guacamole/api/session/data/mysql/connections?token=${token.value}`)
    const data = await res.json()

    if (data && typeof data === 'object' && !data.message) {
      connections.value = data
    } else {
      console.warn("No connections:", data)
    }
  } catch (err) {
    console.error("API error:", err)
  }
})
</script>

<style scoped>
.dashboard {
  max-width: 1000px;
  margin: 4rem auto;
  padding: 2rem;
  background: #ffffff;
  border-radius: 12px;
  box-shadow: 0 4px 16px rgba(0,0,0,0.06);
  text-align: center;
}

h1 {
  font-size: 2rem;
  margin-bottom: 2rem;
  color: #333;
}

.grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
  gap: 1.5rem;
}

.empty-message {
  color: #999;
  font-style: italic;
  font-size: 1.1rem;
}
</style>
