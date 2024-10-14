export const caddy_header = (config) =>
  `{
    email ${config.ADMIN_EMAIL}
    log {
        output stdout
        format console
    }
    acme_dns cloudflare ${config.CLOUDFLARE_API_TOKEN}
}

(auth) {
    basic_auth {
        admin ${config.BASIC_AUTH}
    }
}

telescope.${config.DOMAIN} {

    @telescope {
        path /telescope*
        path /vendor*
    }
    route @telescope {

        reverse_proxy api:8000
        encode gzip
    }
    @telescope_root {
        not path /telescope*
        not path /vendor*
    }
    redir @telescope_root /telescope
}
`
export const caddy_service = (url, proxy_service, basic_auth = false) =>
  `${url} {
    encode gzip
    reverse_proxy ${proxy_service}
    ${basic_auth ? 'import auth' : ''}
}`

