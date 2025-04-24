import { defineStore } from 'pinia'

export const useAuthStore = defineStore('auth', {
  state: () => ({ token: null }),
  actions: {
    async login(username, password) {
      const res = await fetch('/guacamole/api/tokens', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ username, password })
      })
      const data = await res.json()
      if (data.authToken) this.token = data.authToken
      else throw new Error('Invalid credentials')
    },
    logout() {
      this.token = null
    }
  }
})
