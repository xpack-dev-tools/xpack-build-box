set -o errexit
docker system prune -f

# ubuntu:10.04 - lucy - 2010-2015, 2.11.1
# ubuntu:12.04 - precise - 2012-2019, 2.15
# ubuntu:14.04 - trusty - 2014-2022, 2.19
# ubuntu:16.04 - xenial - 2016-2024, 2.23
# ubuntu:18.04 - bionic - 2018-2028, 2.27
# ubuntu:20.04 - focal - 2020-2-30, ?

bash ~/Downloads/xpack-build-box.git/ubuntu/14/arm64-build.sh
bash ~/Downloads/xpack-build-box.git/ubuntu/14/armhf-build.sh
bash ~/Downloads/xpack-build-box.git/ubuntu/16/arm64-build.sh
bash ~/Downloads/xpack-build-box.git/ubuntu/16/armhf-build.sh
bash ~/Downloads/xpack-build-box.git/ubuntu/18/arm64-build.sh
bash ~/Downloads/xpack-build-box.git/ubuntu/18/armhf-build.sh

bash ~/Downloads/xpack-build-box.git/ubuntu/14-updated/arm64-build-v3.1.sh
bash ~/Downloads/xpack-build-box.git/ubuntu/14-updated/armhf-build-v3.1.sh
bash ~/Downloads/xpack-build-box.git/ubuntu/16-updated/arm64-build-v3.1.sh
bash ~/Downloads/xpack-build-box.git/ubuntu/16-updated/armhf-build-v3.1.sh
bash ~/Downloads/xpack-build-box.git/ubuntu/18-updated/arm64-build-v3.1.sh
bash ~/Downloads/xpack-build-box.git/ubuntu/18-updated/armhf-build-v3.1.sh

bash ~/Downloads/xpack-build-box.git/ubuntu/14-develop/arm64-build-v3.1.sh
bash ~/Downloads/xpack-build-box.git/ubuntu/14-develop/armhf-build-v3.1.sh
bash ~/Downloads/xpack-build-box.git/ubuntu/16-develop/arm64-build-v3.1.sh
bash ~/Downloads/xpack-build-box.git/ubuntu/16-develop/armhf-build-v3.1.sh
bash ~/Downloads/xpack-build-box.git/ubuntu/18-develop/arm64-build-v3.1.sh
bash ~/Downloads/xpack-build-box.git/ubuntu/18-develop/armhf-build-v3.1.sh

bash ~/Downloads/xpack-build-box.git/ubuntu/14-tex/arm64-build-v3.1.sh
bash ~/Downloads/xpack-build-box.git/ubuntu/14-tex/armhf-build-v3.1.sh
bash ~/Downloads/xpack-build-box.git/ubuntu/16-tex/arm64-build-v3.1.sh
bash ~/Downloads/xpack-build-box.git/ubuntu/16-tex/armhf-build-v3.1.sh
bash ~/Downloads/xpack-build-box.git/ubuntu/18-tex/arm64-build-v3.1.sh
bash ~/Downloads/xpack-build-box.git/ubuntu/18-tex/armhf-build-v3.1.sh

bash ~/Downloads/xpack-build-box.git/ubuntu/14-bootstrap/arm64-build-v3.1.sh
bash ~/Downloads/xpack-build-box.git/ubuntu/14-bootstrap/armhf-build-v3.1.sh
bash ~/Downloads/xpack-build-box.git/ubuntu/16-bootstrap/arm64-build-v3.1.sh
bash ~/Downloads/xpack-build-box.git/ubuntu/16-bootstrap/armhf-build-v3.1.sh
bash ~/Downloads/xpack-build-box.git/ubuntu/18-bootstrap/arm64-build-v3.1.sh
bash ~/Downloads/xpack-build-box.git/ubuntu/18-bootstrap/armhf-build-v3.1.sh

bash ~/Downloads/xpack-build-box.git/ubuntu/14-xbb/arm64-build-v3.1.sh
bash ~/Downloads/xpack-build-box.git/ubuntu/14-xbb/armhf-build-v3.1.sh
bash ~/Downloads/xpack-build-box.git/ubuntu/16-xbb/arm64-build-v3.1.sh
bash ~/Downloads/xpack-build-box.git/ubuntu/16-xbb/armhf-build-v3.1.sh
bash ~/Downloads/xpack-build-box.git/ubuntu/18-xbb/arm64-build-v3.1.sh
bash ~/Downloads/xpack-build-box.git/ubuntu/18-xbb/armhf-build-v3.1.sh

