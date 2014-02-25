require 'sinatra'
require 'yaml'
require 'ap'

get '/' do
    <<-EOHTML
<html>
    <head>
        <title></title>
    </head>

    <body>#{env['REQUEST_METHOD'].downcase + params.to_s}</body>
</html>
    EOHTML
end

get '/submit' do
    <<-EOHTML
<html>
    <head>
        <title></title>
    </head>

    <body>#{params.to_hash.to_yaml}</body>
</html>
    EOHTML
end

get '/form' do
    <<-EOHTML
<html>
    <body>
        <form action="/submit">
            <input name="param"/>
        </fom>
    </body>
</html>
    EOHTML
end
