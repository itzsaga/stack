const redirectRules = JSON.parse('${REDIRECT_RULES}');
const corsRules = JSON.parse('${CORS_RULES}')

const parsedRedirectRules = redirectRules.map(function (rule) {
    return {
        source: new RegExp(rule.source),
        target: rule.target,
        permanent: rule.permanent
    }
})

const corsEnabled = corsRules.enabled
const allowMethodsHeader = {value: corsRules.allowed_methods.join(',') };
const allowHeadersHeader = { value: corsRules.allowed_headers.join(',') };
const maxAgeHeader = { value: `$${corsRules.max_age}`};
const varyHeader = {value: "Origin" };
const allowedOrigins = {};
for (let i = 0; i < corsRules.allowed_origins.length; i++) {
    allowedOrigins[corsRules.allowed_origins[i]] = true;
}
const allowAllOrigins = allowedOrigins['*'] ? true : false;

function handler (event) {
    const request = event.request;
    const method = request.method;
    const uri = request.uri;
    const headers = request.headers
    const host = headers['host'] ? headers['host'].value : '';
    const protocol = 'https'

    // Construct the full URL.
    const fullUrl = `$${protocol}://$${host}$${uri}`;

    /////////////////////////////////////////////////////////////
    /// Step 1: Apply the redirect rules
    /////////////////////////////////////////////////////////////
    if(host){
        for (let i = 0; i < parsedRedirectRules.length; i++) {
            const rule = parsedRedirectRules[i]
            const match = fullUrl.match(rule.source);

            if (match) {
                // Replace placeholders in the target URL with the matched groups.
                const newLocation = rule.target.replace(/\$(\d+)/g, function (_, group){ return match[group] || ''});

                // Return a 301 redirect response.
                return {
                    statusCode: rule.permanent ? 301 : 302,
                    statusDescription: rule.permanent ? 'Moved Permanently' : 'Moved Temporarily',
                    headers: {
                        location: { value: newLocation }
                    }
                };
            }
        }
    }

    /////////////////////////////////////////////////////////////
    /// Step 2: Apply the CORS rules
    /////////////////////////////////////////////////////////////
    if(corsEnabled){
        const originHeader = headers['origin'] ? headers['origin'].value : '';
        if (method === 'OPTIONS') {
            if (allowAllOrigins || allowedOrigins[originHeader]){
                return {
                    statusCode: 200,
                    statusDescription: 'OK',
                    headers: {
                        'access-control-allow-origin': { value: originHeader },
                        'access-control-allow-methods': allowMethodsHeader,
                        'access-control-allow-headers': allowHeadersHeader,
                        'access-control-max-age': maxAgeHeader,
                        'vary': varyHeader
                    }
                };
            } else {
                return {
                    statusCode: 403,
                    statusDescription: 'Denied'
                };
            }
        }
    }

    /////////////////////////////////////////////////////////////
    /// Step 3: If no rule matches, proceed with the original request.
    /////////////////////////////////////////////////////////////
    return request;
}
