<template>
  <div class="content-box" ref="contentBox">
    <div v-if="blocked > 0 && !allowRemote" class="remote-bar">
      <span>{{ $t('remoteImagesBlocked', {total: blocked}) }}</span>
      <a class="remote-btn" @click="allowRemote = true">{{ $t('showRemoteImages') }}</a>
    </div>
    <!--
      邮件 HTML 已经过白名单清理，再放进 sandbox iframe：
      - 不给 allow-scripts：iframe 内任何脚本、事件属性都不会执行
      - 不给 allow-forms / allow-popups / allow-top-navigation：不能提交表单、弹窗或跳走父页面
      - 只保留 allow-same-origin，供父页面在不运行脚本的前提下读取尺寸、接管链接点击
    -->
    <iframe
        ref="frame"
        class="content-html"
        sandbox="allow-same-origin"
        referrerpolicy="no-referrer"
        :srcdoc="srcdoc"
        @load="onFrameLoad"
        title="email"
    ></iframe>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted, onBeforeUnmount } from 'vue'
import { sanitizeEmailHtml, isSafeLink } from '@/utils/email-sanitize.js'
import { useSettingStore } from '@/store/setting.js'
import { toOssDomain } from '@/utils/convert.js'

const props = defineProps({
  html: {
    type: String,
    required: true
  }
})

const settingStore = useSettingStore()
const frame = ref(null)
const contentBox = ref(null)
const allowRemote = ref(false)
let resizeObserver = null

function trustedPrefixes() {
  const prefixes = [window.location.origin + '/']
  const oss = toOssDomain(settingStore.settings?.r2Domain)
  if (oss) prefixes.push(oss + '/')
  return prefixes
}

function cspOrigins() {
  const origins = ["'self'"]
  try {
    const oss = toOssDomain(settingStore.settings?.r2Domain)
    if (oss) origins.push(new URL(oss).origin)
  } catch { /* ignore */ }
  return origins.join(' ')
}

const sanitized = computed(() => sanitizeEmailHtml(props.html, {
  allowRemote: allowRemote.value,
  trustedPrefixes: trustedPrefixes()
}))

const blocked = ref(0)

const srcdoc = computed(() => {
  const { html } = sanitized.value
  const remote = allowRemote.value ? ' https: http:' : ''
  const csp = [
    "default-src 'none'",
    "script-src 'none'",
    "object-src 'none'",
    "frame-src 'none'",
    "form-action 'none'",
    "base-uri 'none'",
    `img-src data: cid: ${cspOrigins()}${remote}`,
    `font-src data:${remote}`,
    "style-src 'unsafe-inline'"
  ].join('; ')

  return `<!DOCTYPE html><html><head><meta charset="utf-8">
<meta http-equiv="Content-Security-Policy" content="${csp}">
<meta name="referrer" content="no-referrer">
<style>
  html, body { margin: 0; padding: 0; background: #FFFFFF; overflow: hidden; }
  body {
    font-family: Inter, 'Helvetica Neue', Helvetica, 'PingFang SC',
                'Hiragino Sans GB', 'Microsoft YaHei', '微软雅黑', Arial, sans-serif;
    font-size: 14px;
    line-height: 1.5;
    color: #13181D;
    word-break: break-word;
  }
  h1, h2, h3, h4 { font-size: 18px; font-weight: 700; }
  p { margin: 0; }
  a { text-decoration: none; color: #0E70DF; }
  .mail-body { width: fit-content; height: fit-content; min-width: 100%; }
  img:not(table img) { max-width: 100%; height: auto !important; }
</style></head><body>${html}</body></html>`
})

watch(sanitized, value => { blocked.value = value.blocked }, { immediate: true })

// 换邮件时重新默认拦截远程图片
watch(() => props.html, () => { allowRemote.value = false })

function frameDoc() {
  try {
    return frame.value?.contentDocument || null
  } catch {
    return null
  }
}

function autoScale() {
  const doc = frameDoc()
  const box = contentBox.value
  if (!doc || !doc.body || !box) return
  const content = doc.querySelector('.mail-body') || doc.body

  doc.documentElement.style.zoom = ''
  const parentWidth = box.offsetWidth
  const childWidth = content.scrollWidth
  if (!parentWidth || !childWidth) return

  const scale = Math.min(1, parentWidth / childWidth)
  doc.documentElement.style.zoom = scale === 1 ? '' : String(scale)
  const height = Math.ceil(doc.documentElement.getBoundingClientRect().height || doc.body.scrollHeight * scale)
  frame.value.style.height = Math.max(height, 20) + 'px'
}

function onLinkClick(event) {
  const anchor = event.target?.closest?.('a')
  if (!anchor) return
  const href = anchor.getAttribute('href')
  if (!href) {
    event.preventDefault()
    return
  }
  if (href.startsWith('#')) return
  event.preventDefault()
  if (!isSafeLink(href)) return
  // 由父页面受控打开，切断 opener 与 referrer
  window.open(anchor.href, '_blank', 'noopener,noreferrer')
}

function onFrameLoad() {
  const doc = frameDoc()
  if (!doc) return
  doc.addEventListener('click', onLinkClick)
  doc.querySelectorAll('img').forEach(img => {
    if (!img.complete) img.addEventListener('load', autoScale, { once: true })
  })
  autoScale()
}

onMounted(() => {
  if (window.ResizeObserver && contentBox.value) {
    resizeObserver = new ResizeObserver(() => autoScale())
    resizeObserver.observe(contentBox.value)
  }
})

onBeforeUnmount(() => {
  resizeObserver?.disconnect()
})
</script>

<style scoped>
.content-box {
  width: 100%;
  height: 100%;
  overflow: hidden;
  font-family: Inter, "Helvetica Neue", Helvetica, "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", "微软雅黑", Arial, sans-serif;
}

.content-html {
  display: block;
  width: 100%;
  border: 0;
  min-height: 20px;
}

.remote-bar {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 6px 10px;
  margin-bottom: 8px;
  font-size: 13px;
  border-radius: 4px;
  background: var(--el-fill-color-light, #f5f7fa);
  color: var(--el-text-color-regular, #606266);
}

.remote-btn {
  cursor: pointer;
  color: var(--el-color-primary, #409eff);
}
</style>
