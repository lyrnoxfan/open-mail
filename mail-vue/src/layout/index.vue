<template>
  <el-container class="layout">
    <el-aside
        class="aside"
        :class="uiStore.asideShow ? 'aside-show' : 'el-aside-hide'">
      <Aside />
    </el-aside>
    <div
        :class="(uiStore.asideShow && isMobile)? 'overlay-show':'overlay-hide'"
        @click="uiStore.asideShow = false"
    ></div>
    <el-container class="main-container">
      <el-header class="navbar">
        <Header />
      </el-header>
      <el-main class="main">
        <Main />
      </el-main>
      <!-- 移动端底部 Tab -->
      <nav class="tabbar" v-if="isMobileTab">
        <div class="tab" :class="{active: tabActive('email')}" @click="goTab('email')">
          <Icon icon="hugeicons:mailbox-01" width="24" height="24" />
          <span>{{ $t('inbox') }}</span>
        </div>
        <div class="tab" :class="{active: tabActive('star')}" @click="goTab('star')">
          <Icon icon="solar:star-line-duotone" width="24" height="24" />
          <span>{{ $t('starred') }}</span>
        </div>
        <div class="tab compose-tab" @click="openCompose" v-perm="'email:send'">
          <div class="compose-btn">
            <Icon icon="material-symbols:edit-outline-sharp" width="24" height="24" />
          </div>
        </div>
        <div class="tab" @click="toggleAside">
          <Icon icon="solar:hamburger-menu-linear" width="24" height="24" />
          <span>{{ $t('more') }}</span>
        </div>
        <div class="tab" :class="{active: tabActive('setting')}" @click="goTab('setting')">
          <Icon icon="fluent:settings-48-regular" width="24" height="24" />
          <span>{{ $t('settings') }}</span>
        </div>
      </nav>
    </el-container>
  </el-container>
  <writer ref="writerRef" />
</template>

<script setup>
import Aside from '@/layout/aside/index.vue'
import Header from '@/layout/header/index.vue'
import Main from '@/layout/main/index.vue'
import { ref, onMounted, onBeforeUnmount, computed } from 'vue'
import { useUiStore } from "@/store/ui.js";
import { useRoute, useRouter } from "vue-router";
import { Icon } from "@iconify/vue";
import writer from '@/layout/write/index.vue'

const uiStore = useUiStore();
const route = useRoute();
const router = useRouter();
const writerRef = ref({})
const isMobile = ref(window.innerWidth < 1025)
const isMobileTab = ref(window.innerWidth < 768)
const handleResize = () => {
  isMobile.value = window.innerWidth < 1025
  isMobileTab.value = window.innerWidth < 768
  uiStore.asideShow = window.innerWidth > 1024;
}

const tabActive = (name) => route.meta.name === name
const goTab = (name) => {
  uiStore.asideShow = false
  router.push({ name })
}
const toggleAside = () => { uiStore.asideShow = !uiStore.asideShow }
const openCompose = () => { uiStore.writerRef?.open() }

onMounted(() => {
  uiStore.writerRef = writerRef
  window.addEventListener('resize', handleResize)
  handleResize()
})

onBeforeUnmount(() => {
  window.removeEventListener('resize', handleResize)
})
</script>

<style lang="scss" scoped>
.layout {
  height: 100%;
  position: fixed;
  width: 100%;
  top: 0;
  left: 0;
  overflow: hidden;
  background: var(--bg);
}

/* ---------- 桌面端侧边栏 ---------- */
.aside {
  width: 264px;
  background: var(--card);
  border-right: 1px solid var(--separator);
  transition: margin .2s ease, transform .2s ease;
  overflow: hidden;
  z-index: 60;
}
.el-aside-hide {
  margin-left: -264px;
  @media (max-width: 1025px) {
    margin-left: 0;
    position: fixed;
    top: 0;
    left: 0;
    height: 100%;
    z-index: 100;
    transform: translateX(-105%);
    box-shadow: var(--shadow-md);
  }
}
.aside-show {
  @media (max-width: 1025px) {
    position: fixed;
    top: 0;
    left: 0;
    height: 100%;
    z-index: 101;
    transform: translateX(0);
    box-shadow: var(--shadow-md);
  }
}

.main-container {
  min-height: 100%;
  background: var(--bg);
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

/* ---------- 顶栏：iOS 导航栏风 ---------- */
.navbar {
  height: 56px;
  min-height: 56px;
  background: var(--navbar-bg);
  -webkit-backdrop-filter: blur(20px);
  backdrop-filter: blur(20px);
  border-bottom: 1px solid var(--separator);
  padding: 0 8px 0 4px;
  z-index: 50;
}

/* ---------- 主内容 ---------- */
.main {
  padding: 0;
  flex: 1;
  overflow: hidden;
  background: var(--bg);
}

/* ---------- 移动端底部 Tab ---------- */
.tabbar {
  display: none;
  @media (max-width: 767px) {
    display: flex;
  }
  align-items: stretch;
  background: var(--tabbar-bg);
  -webkit-backdrop-filter: blur(20px);
  backdrop-filter: blur(20px);
  border-top: 1px solid var(--separator);
  padding-bottom: env(safe-area-inset-bottom);
  z-index: 50;
  min-height: 58px;
  .tab {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 2px;
    color: var(--text-3);
    font-size: 10px;
    font-weight: 500;
    padding: 6px 0 8px;
    cursor: pointer;
    min-height: 48px;
    &.active { color: var(--accent); }
    &:active { opacity: .6; }
  }
  .compose-tab {
    flex: 1;
    .compose-btn {
      width: 52px;
      height: 52px;
      border-radius: 50%;
      background: var(--accent);
      color: #fff;
      display: flex;
      align-items: center;
      justify-content: center;
      margin-top: -18px;
      box-shadow: 0 4px 12px rgba(207, 99, 144, .35);
      border: 4px solid var(--bg);
    }
    &:active .compose-btn { opacity: .85; }
  }
}

.overlay-show {
  position: fixed;
  top: 0;
  left: 0;
  width: 100vw;
  height: 100vh;
  background: rgba(0, 0, 0, 0.4);
  z-index: 99;
  transition: opacity 0.25s;
}
.overlay-hide {
  display: none;
}
</style>
