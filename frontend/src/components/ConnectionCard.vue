<template>
  <div class="card" @click="connect">
    <h3>{{ conn.name || 'Unnamed' }}</h3>
    <p>Натисніть, щоб підключитись</p>
  </div>
</template>

<script setup>
const props = defineProps({
  conn: Object,
  id: String,
  token: String
})

function connect() {
  const baseUrl = window.location.origin;
  window.location.href = `${baseUrl}/guacamole/#/client/${props.id}?token=${props.token}`;
}
</script>

<style scoped>
.card {
  background: #f7f7f7;
  border-radius: 8px;
  padding: 1.5rem;
  box-shadow: 0 2px 6px rgba(0,0,0,0.1);
  cursor: pointer;
  transition: transform 0.2s ease, box-shadow 0.2s ease;
  text-align: left;
}

.card:hover {
  transform: translateY(-3px);
  box-shadow: 0 6px 12px rgba(0,0,0,0.1);
}

.card h3 {
  margin: 0 0 0.5rem;
  color: #333;
}

.card p {
  margin: 0;
  color: #666;
  font-size: 0.9rem;
}
</style>
