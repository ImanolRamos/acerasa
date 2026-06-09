import { createRouter, createWebHistory } from 'vue-router'
import AppLayout from '../layouts/AppLayout.vue'
import Login from '../views/Login.vue'
import HistoricalView from '../views/HistoricalView.vue'
import RealtimeView from '../views/RealtimeView.vue'
import InfoView from '../views/InfoView.vue'

const routes = [
  {
    path: '/login',
    component: Login,
  },
  {
    path: '/',
    component: AppLayout,
    meta: { requiresAuth: true },
    children: [
      {
        path: '',
        redirect: '/historic'
      },
      {
        path: '/historic',
        component: HistoricalView,
      },
      {
        path: '/realtime',
        component: RealtimeView,
      },
      {
        path: '/info',
        component: InfoView,
      },
    ],
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
    return '/historic'
  }
})

export default router