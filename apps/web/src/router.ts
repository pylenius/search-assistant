import { createRouter, createWebHistory, type RouteRecordRaw } from 'vue-router'

const routes: RouteRecordRaw[] = [
  {
    path: '/',
    name: 'landing',
    component: () => import('./views/LandingView.vue'),
  },
  {
    path: '/s/:slug',
    name: 'search',
    component: () => import('./views/SearchView.vue'),
    props: true,
  },
  {
    path: '/s/:slug/manage',
    name: 'manage',
    component: () => import('./views/ManageView.vue'),
    props: true,
  },
]

export const router = createRouter({
  history: createWebHistory(),
  routes,
})
