PORT?=9009

compile:
	@./node_modules/.bin/hem build

run_server:
	@./node_modules/.bin/hem server -d -p $(PORT)

upload:
	@s3cmd sync --acl-public ./public/ s3://slowpta.jawsapps.com

clean:
	@rm -f ./public/application.*

server: clean run_server
deploy: clean compile upload clean
