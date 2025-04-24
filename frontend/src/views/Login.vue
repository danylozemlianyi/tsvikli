<template>
  <div class="login-container">
    <img src="@/assets/logo.png" alt="Tsvikli Logo" class="logo" />
    <h1>Login</h1>
    <form @submit.prevent="handleLogin">
      <input v-model="username" placeholder="Username" />
      <input type="password" v-model="password" placeholder="Password" />
      <button type="submit">Login</button>
    </form>
    <p v-if="error" class="error">{{ error }}</p>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useAuthStore } from '../stores/auth'
import { useRouter } from 'vue-router'

const username = ref('')
const password = ref('')
const error = ref(null)
const store = useAuthStore()
const router = useRouter()

async function handleLogin() {
  try {
    await store.login(username.value, password.value)
    router.push('/dashboard')
  } catch (err) {
    error.value = err.message
  }
}
</script>

<style scoped>
.login-container {
  max-width: 400px;
  margin: 10vh auto;
  background: white;
  padding: 2rem;
  border-radius: 10px;
  box-shadow: 0 2px 10px rgba(0,0,0,0.1);
  display: flex;
  flex-direction: column;
  gap: 1rem;
  align-items: center;
}

.logo {
  width: 400px;
  height: auto;
  margin-bottom: 0.5rem;
}

h1 {
  margin-bottom: 0.5rem;
  font-size: 1.5rem;
}

form {
  width: 100%;
  display: flex;
  flex-direction: column;
  gap: 0.8rem;
}

input {
  width: 100%;
  padding: 0.6rem;
  border: 1px solid #333;
  border-radius: 4px;
  font-size: 1rem;
}

button {
  width: 105%;
  padding: 0.7rem;
  background-color: #4CAF50;
  color: white;
  border: none;
  border-radius: 4px;
  font-weight: bold;
  font-size: 1rem;
  cursor: pointer;
  transition: background 0.2s;
}

button:hover {
  background-color: #45a049;
}

.error {
  color: #c62828;
  font-weight: 500;
  text-align: center;
}
</style>
