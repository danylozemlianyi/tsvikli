<template>
  <div class="card" @click="connect">
    <h3>{{ conn.name || 'Unnamed' }}</h3>
    <p>Натисніть, щоб підключитись</p>
  </div>
</template>

<script setup>
const props = defineProps({
  conn: Object,
  id: String
})

function connect() {
  const baseUrl = window.location.origin;
  const token = sessionStorage.getItem("guac_token");

  const url = `${baseUrl}/guacamole/#/client?GUAC_ID=${props.id}&GUAC_TYPE=c&GUAC_DATA_SOURCE=mysql&token=${token}`;

  const width = window.screen.availWidth;
  const height = window.screen.availHeight;

  const newWindow = window.open(
    url,
    "_blank",
    `toolbar=no,menubar=no,scrollbars=no,resizable=yes,location=no,status=no,width=${width},height=${height},top=0,left=0`
  );

  if (!newWindow) {
    alert("Будь ласка, дозвольте спливаючі вікна для сайту.");
  }
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
