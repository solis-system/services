export const caddy_header = (domain, email, basic_auth) =>
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
}

telescope.${domain} {

    @telescope {
        path /telescope*
    }
    route @telescope {
        import auth
        reverse_proxy api:8000
        encode gzip
    }
    @telescope_root {
        not path /telescope*
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
