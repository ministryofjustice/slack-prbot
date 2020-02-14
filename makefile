IMAGE := cloud-platform-slack-prbot
VERSION := 1.2
ORG := ministryofjustice
TAGGED := $(ORG)/$(IMAGE):$(VERSION)

build: .built-docker-image

clean:
	docker rmi $(IMAGE) --force
	docker rmi $(TAGGED) --force
	rm .built-docker-image

.built-docker-image: Dockerfile Gemfile config.ru web.rb lib/pr.rb $(wildcard lib/pr/*.rb)
	docker build -t $(IMAGE) .
	docker tag $(IMAGE) $(TAGGED)
	touch .built-docker-image

docker-push: .built-docker-image
	docker push $(TAGGED)

# Run a local copy of the PR bot.
# Set env vars before invoking.
# See example.env for details
#
# To test the bot, when running locally, execute this:
#
#    curl --data "token=whtoken&text=for%20team%20webops" http://localhost:9292/webhook
#
# Where 'whtoken' is whatever WEBHOOK_TOKEN is set to.
#
# The response should look like this:
#
# { "text": "The following PRs are open:
# • <https://github.com/ministryofjustice/pvb2-deploy/pull/230|pvb2-deploy#230: *Add the new quantum IP for production*> by rossjones (38d old)
# ...
# • <https://github.com/ministryofjustice/cloud-platform-multi-container-demo-app/pull/5|cloud-platform-multi-container-demo-app#5: *Add HTTP basic authentication to the app.*> by digitalronin (2d old)"}
#
server: .built-docker-image
	docker run \
		-p 9292:9292 \
		-e WEBHOOK_TOKEN=$${WEBHOOK_TOKEN} \
		-e GH_ORG=$${GH_ORG} \
		-e GH_TOKEN=$${GH_TOKEN} \
		-it $(TAGGED)
