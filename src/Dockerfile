##
# Interact with the base image:
#   docker run --rm -it --entrypoint bash public.ecr.aws/lambda/ruby:2.7
#
##
# Interact with built container:
# docker run --rm -it --entrypoint bash mitre/serverless-heimdall-pusher-lambda:latest
#
#
##
# Make requests to local container: (https://docs.aws.amazon.com/lambda/latest/dg/images-test.html)
# docker run -p 9000:8080 mitre/serverless-heimdall-pusher-lambda:latest
# curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" -d '{}'
#
##
#
# Build the image
#   docker build -t mitre/serverless-heimdall-pusher-lambda:latest .
#     OR
#   cd terraform/modules/inspec-lambda/; ./build-image.sh

##
# Use Ruby from AWS lambda ECR
#
# https://gallery.ecr.aws/lambda/ruby
#
FROM public.ecr.aws/lambda/ruby:2.7

##
# Copy over the function code and bundle install
#
COPY lambda_function.rb Gemfile Gemfile.lock .ruby-version /var/task/
RUN bundle install --path vendor/bundle/

##
# Set the handler
#
# https://docs.aws.amazon.com/lambda/latest/dg/images-create.html
#
CMD [ "lambda_function.lambda_handler" ]
