VERSION=$(cat './version')

docker build -t mitre/serverless-heimdall-pusher-lambda:$VERSION ./src/
docker tag mitre/serverless-heimdall-pusher-lambda:$VERSION mitre/serverless-heimdall-pusher-lambda:latest

# docker save mitre/serverless-heimdall-pusher-lambda:$VERSION > serverless-heimdall-pusher-lambda.tar
