# fiks.me: A Simple Tool for Local App Debugging

Just as lvh.voronenko.net, but branding neutral ;)

# Introduction:
When it comes to developing and debugging applications locally, having a reliable and efficient tool is crucial. One such tool is the domain lvh.me, which acts as a local DNS resolver, 
redirecting all addresses to the localhost. I used it for a long time, but was always missing normal green seal https certificates for this domain. I used for a long time lvh.voronenko.net
which acts in the same way, but as number of mine clients started to use it too, question appeared - can it be more "neutral" ?

Thus I have registered fiks.im, which will valid at least until 2033.  You could be sure, that you will get all subdomains of this domain (except www which points to this repo) to localhost,
and fqdn will be neutral enough to be used by most of the teams.

Thus you will be able to use domains like app.fiks.im,  api.fiks.im , etc

## What is fiks.me?
fiks.im is a domain name that stands close to "we are fixing (smth)". It is specifically designed to simplify mine local app debugging by resolving all domain addresses to the localhost IP address (127.0.0.1). 
This means that any request made to a fiks.im subdomain will be automatically redirected to your local machine, allowing you to test and debug your application in a controlled environment.

My usual setup is based on a traefik, check https://github.com/Voronenko/traefik2-compose-template for details. In this repo I will publish basic traefik docker-compose, and green seal certificates,
that you are free to use. They will be updated regularly, to ensure that you always will get authorized https connection locally.

Benefits of using fiks.im:
1. Simplicity: With fiks.im, there is no need to modify your hosts file or set up complex DNS configurations. It provides a straightforward solution for redirecting all requests to your local development environment.

2. Easy setup: Using fiks.me is as simple as including the desired subdomain in your application's URL. If you want https, there is a need to take a look on this repo and configure 
traefik once. For details of traefik configuration and few useful applications, please check out https://github.com/Voronenko/traefik2-compose-template . 
This makes fiks.im an ideal tool for myself (and hopefully other developers) who want a quick and hassle-free debugging experience.

3. Versatility: Lv.me supports both HTTP and HTTPS, allowing you to test and debug applications that require secure connections. 
This flexibility ensures that you can replicate various scenarios and thoroughly test your app's functionality.

## How to use fiks.im:

1. Include the desired subdomain: To use fiks.im, simply include the desired subdomain as a prefix to your localhost address. 
For example, if your app runs on localhost:3000, accessing it through myapp.fiks.im:3000 will redirect the request to your local development environment. If you would use traefik,
you will be able to wrap application behind usual http and https ports, and thus access your application just as https://myapp.fiks.im or http://myapp.fiks.im

2. Testing multiple subdomains: fiks.im allows you to test multiple subdomains simultaneously. For example, you can access subdomain1.fiks.im, subdomain2.fiks.im, and so on. 
This feature is particularly useful when testing multi-tenant applications or different sections of your app.

3. HTTPS support: Repeating, if your application requires HTTPS, fiks.im has got you covered. By using the subdomain with the HTTPS protocol, traefik and fiks.im will ensure that the request 
is redirected securely to your local environment.

Should you have any questions, feel free to contact
