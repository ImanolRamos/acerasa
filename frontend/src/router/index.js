import { createRouter, createWebHistory } from 'vue-router'
import Login from '../views/Login.vue'
import HistoricalView from '../views/HistoricalView.vue'

const routes = [
  {
    path: '/login',
    component: Login,
  },
  {
    path: '/',
    component: HistoricalView,
    meta: { requiresAuth: true },
  },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

router.beforeEach((to) => {
  const token = localStorage.getItem('token')

  if (to.meta.requiresAuth && !token) {
    return '/login'
  }

  if (to.path === '/login' && token) {
    return '/'
  }
})

export default router