import DOMPurify from 'dompurify'

// 收到的邮件 HTML 一律视为不可信内容：
// 1. 白名单清理（去掉脚本、事件属性、危险 URL、表单和各类活动嵌入）
// 2. 远程资源（图片、背景、字体）默认拦截，用户逐封允许后才加载
// 3. 清理结果交给 sandbox iframe 渲染（见 components/shadow-html）

const SAFE_LINK_PROTOCOLS = ['http:', 'https:', 'mailto:', 'tel:']

const FORBID_TAGS = [
    'script', 'noscript', 'iframe', 'frame', 'frameset', 'object', 'embed', 'applet',
    'form', 'input', 'button', 'textarea', 'select', 'option', 'optgroup', 'datalist', 'output',
    'base', 'meta', 'link', 'portal', 'template', 'slot',
    'video', 'audio', 'source', 'track', 'picture',
    'svg', 'math', 'dialog'
]

const FORBID_ATTR = ['srcset', 'imagesrcset', 'ping', 'formaction', 'action', 'xlink:href', 'autofocus', 'srcdoc']

// 只允许这些协议，或不带协议的相对地址 / 锚点
const ALLOWED_URI_REGEXP = /^(?:(?:https?|mailto|tel|cid):|[^a-z]|[a-z+.-]+(?:[^a-z+.\-:]|$))/i

const DANGEROUS_CSS = /(expression\s*\(|behavior\s*:|-moz-binding|javascript:|vbscript:|@import)/gi
const CSS_URL = /url\(\s*(['"]?)(.*?)\1\s*\)/gi

function isRemoteUrl(url) {
    return /^(https?:)?\/\//i.test((url || '').trim())
}

function isTrusted(url, trustedPrefixes) {
    const value = (url || '').trim()
    if (!isRemoteUrl(value)) return true // 相对地址、data:、cid: 不涉及第三方
    let abs
    try {
        abs = new URL(value, window.location.href).href
    } catch {
        return false
    }
    return trustedPrefixes.some(prefix => prefix && abs.startsWith(prefix))
}

function cleanCss(css, ctx) {
    if (!css) return css
    let out = css.replace(DANGEROUS_CSS, '/* blocked */')
    out = out.replace(CSS_URL, (match, quote, url) => {
        const value = (url || '').trim()
        if (/^(javascript|vbscript):/i.test(value)) return 'none'
        if (/^data:/i.test(value) && !/^data:image\/(png|gif|jpe?g|webp|bmp);/i.test(value)) return 'none'
        if (isRemoteUrl(value) && !isTrusted(value, ctx.trustedPrefixes)) {
            if (!ctx.allowRemote) {
                ctx.blocked++
                return 'none'
            }
        }
        return match
    })
    return out
}

export function isSafeLink(href) {
    if (!href) return false
    try {
        const url = new URL(href, window.location.href)
        return SAFE_LINK_PROTOCOLS.includes(url.protocol)
    } catch {
        return false
    }
}

/**
 * @param {string} rawHtml 邮件原始 HTML
 * @param {{allowRemote?: boolean, trustedPrefixes?: string[]}} options
 * @returns {{html: string, blocked: number}}
 */
export function sanitizeEmailHtml(rawHtml, options = {}) {
    const ctx = {
        allowRemote: !!options.allowRemote,
        trustedPrefixes: (options.trustedPrefixes || []).filter(Boolean),
        blocked: 0
    }

    // 把 <head> 里的 <style> 和 <body style> 一起保留下来，再整体清理
    const parsed = new DOMParser().parseFromString(rawHtml || '', 'text/html')
    const headStyles = Array.from(parsed.head?.querySelectorAll('style') || [])
        .map(style => `<style>${style.textContent}</style>`)
        .join('')
    const bodyStyle = parsed.body?.getAttribute('style') || ''
    // 注意：必须在 DOMParser 生成的惰性文档里操作，不能用当前页面的 document，
    // 否则 innerHTML 时 <img onerror> 之类会在清理前就执行/发起请求
    const wrapper = parsed.createElement('div')
    wrapper.className = 'mail-body'
    if (bodyStyle) wrapper.setAttribute('style', bodyStyle)
    while (parsed.body && parsed.body.firstChild) {
        wrapper.appendChild(parsed.body.firstChild)
    }
    const source = headStyles + wrapper.outerHTML

    const purify = DOMPurify(window)

    purify.addHook('uponSanitizeElement', (node, data) => {
        if (data.tagName === 'style') {
            node.textContent = cleanCss(node.textContent, ctx)
        }
    })

    purify.addHook('afterSanitizeAttributes', node => {
        if (node.hasAttribute('style')) {
            node.setAttribute('style', cleanCss(node.getAttribute('style'), ctx))
        }

        for (const attr of ['src', 'background', 'poster']) {
            if (!node.hasAttribute(attr)) continue
            const value = node.getAttribute(attr)
            if (isRemoteUrl(value) && !isTrusted(value, ctx.trustedPrefixes) && !ctx.allowRemote) {
                node.removeAttribute(attr)
                node.setAttribute('data-blocked-' + attr, value)
                ctx.blocked++
            }
        }

        if (node.tagName === 'A') {
            const href = node.getAttribute('href')
            if (href && !href.startsWith('#') && !isSafeLink(href)) {
                node.removeAttribute('href')
            }
            node.setAttribute('rel', 'noopener noreferrer nofollow')
            node.removeAttribute('target')
        }

        if (node.tagName === 'AREA') {
            node.removeAttribute('href')
        }
    })

    const html = purify.sanitize(source, {
        USE_PROFILES: {html: true},
        FORBID_TAGS,
        FORBID_ATTR,
        ADD_TAGS: ['style'],
        ALLOW_DATA_ATTR: false,
        ALLOWED_URI_REGEXP,
        FORCE_BODY: true,
        ALLOW_UNKNOWN_PROTOCOLS: false,
        SANITIZE_NAMED_PROPS: true
    })

    return {html, blocked: ctx.blocked}
}
