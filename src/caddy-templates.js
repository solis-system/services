export const caddy_header = (config) => `
{
    email ${config.ADMIN_EMAIL}
    log {
        output stdout
        format console
    }
}
`
export const caddy_service = (url, proxy_service, basic_auth = false, config) =>
  `${url} {
    encode gzip
    reverse_proxy ${proxy_service}
    tls {
      dns cloudflare ${config.CLOUDFLARE_API_TOKEN}
    }
}`