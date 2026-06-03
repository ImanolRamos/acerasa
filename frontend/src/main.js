import { createApp } from 'vue'
import Root from './Root.vue'

import 'vuetify/styles'
import '@mdi/font/css/materialdesignicons.css'

import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'

import router from './router'

const vuetify = createVuetify({
  components,
  directives,
})

createApp(Root)
  .use(vuetify)
  .use(router)
  .mount('#app')