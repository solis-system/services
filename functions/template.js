export const caddy_header = (email, basic_auth) =>
  `{
    email ${email}
    log {
        output stdout
        format console
    }
}
(auth) {
    basic_auth {
        ${basic_auth}
    }
}`

export const caddy_service = (url, proxy_service, basic_auth = false) =>
  `${url} {
    encode gzip
    reverse_proxy ${proxy_service}
    ${basic_auth ? 'import auth' : ''}
}`
