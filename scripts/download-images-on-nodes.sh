#TRITON_SERVER=nvcr.io/nvidia/tritonserver:23.04-py3
#ML_SERVER=seldonio/mlserver:1.3.2 
#OPENVINO=openvino/model_server:2022.3 
#TORCHSERVE=pytorch/torchserve:0.7.1-cpu
export SCRIPT_DIR=$(dirname "$(realpath "$0")")
export RUNTIME_DIR=${SCRIPT_DIR}/../config/runtimes
export DEFAULT_DIR=${SCRIPT_DIR}/../config/default

# automation
MODELMESH_NAME=$(cat ${DEFAULT_DIR}/config-defaults.yaml |grep modelMeshImage -A1|grep "name"|cut -d: -f2|tr -d " ")
MODELMESH_RUNTIME_NAME=$(cat ${DEFAULT_DIR}/config-defaults.yaml |grep storageHelperImage -A1|grep "name"|cut -d: -f2|tr -d " ")
REST_PROXY_NAME=$(cat ${DEFAULT_DIR}/config-defaults.yaml |grep restProxy -A4|grep "name"|cut -d: -f2|tr -d " ")

MODELMESH_TAG=$(cat ${DEFAULT_DIR}/config-defaults.yaml |grep modelMeshImage -A2|grep "tag"|cut -d: -f2|tr -d " ")
MODELMESH_RUNTIME_TAG=$(cat ${DEFAULT_DIR}/config-defaults.yaml |grep storageHelperImage -A2|grep "tag"|cut -d: -f2|tr -d " ")
REST_PROXY_TAG=$(cat ${DEFAULT_DIR}/config-defaults.yaml |grep restProxy -A5|grep "tag"|cut -d: -f2|tr -d " ")

MODELMESH=${MODELMESH_NAME}:${MODELMESH_TAG}
MODELMESH_RUNTIME=${MODELMESH_RUNTIME_NAME}:${MODELMESH_RUNTIME_TAG}
REST_PROXY=${REST_PROXY_NAME}:${REST_PROXY_TAG}

echo ${MODELMESH}
echo $MODELMESH_RUNTIME
echo $REST_PROXY

echo $SCRIPT_DIR
echo $RUNTIME_DIR
TRITON_SERVER_IMG_NAME=tritonserver
ML_SERVER_IMG_NAME=mlserver
TORCHSERVE_IMG_NAME=torchserve
OPENVINO_IMG_NAME=model_server

TRITON_SERVER_IMG=$(cat ${RUNTIME_DIR}/kustomization.yaml |grep ${TRITON_SERVER_IMG_NAME} -A1|grep "newName"|cut -d: -f2|tr -d " ")
ML_SERVER_IMG=$(cat ${RUNTIME_DIR}/kustomization.yaml |grep ${ML_SERVER_IMG_NAME} -A1|grep "newName"|cut -d: -f2|tr -d " ")
TORCHSERVE_IMG=$(cat ${RUNTIME_DIR}/kustomization.yaml |grep ${TORCHSERVE_IMG_NAME} -A1|grep "newName"|cut -d: -f2|tr -d " ")
OPENVINO_IMG=$(cat ${RUNTIME_DIR}/kustomization.yaml |grep ${OPENVINO_IMG_NAME} -A1|grep "newName"|cut -d: -f2|tr -d " ")

TRITON_SERVER_TAG=$(cat ${RUNTIME_DIR}/kustomization.yaml |grep ${TRITON_SERVER_IMG} -A1|grep "newTag"|cut -d: -f2|tr -d '"'|tr -d " ")
ML_SERVER_TAG=$(cat ${RUNTIME_DIR}/kustomization.yaml |grep ${ML_SERVER_IMG} -A1|grep "newTag"|cut -d: -f2|tr -d '"'|tr -d " ")
TORCHSERVE_TAG=$(cat ${RUNTIME_DIR}/kustomization.yaml |grep ${TORCHSERVE_IMG} -A1|grep "newTag"|cut -d: -f2|tr -d '"'|tr -d " ")
OPENVINO_TAG=$(cat ${RUNTIME_DIR}/kustomization.yaml |grep ${OPENVINO_IMG} -A1|grep "newTag"|cut -d: -f2|tr -d '"'|tr -d " ")

export TRITON_SERVER=${TRITON_SERVER_IMG}:${TRITON_SERVER_TAG}
export ML_SERVER=${ML_SERVER_IMG}:${ML_SERVER_TAG}
export TORCHSERVE=${TORCHSERVE_IMG}:${TORCHSERVE_TAG}
export OPENVINO=${OPENVINO_IMG}:${OPENVINO_TAG}

# Debug purpose
# echo ${TRITON_SERVER}
# echo ${ML_SERVER}
# echo ${TORCHSERVE}
# echo ${OPENVINO}
images=(${TRITON_SERVER} ${ML_SERVER} ${OPENVINO} ${TORCHSERVE} ${MODELMESH} ${MODELMESH_RUNTIME} ${REST_PROXY})

wait_downloading_images(){
  nodeCount=$(oc get node|grep worker|grep -v infra|wc -l)
  expectedTotalCount=$((${#images[@]}*${nodeCount}))
  totalCount=0
  retries=0
  max_retries=10
  echo "Node: ${nodeCount}, Required Images: ${#images[@]}, Expected Downloading Count: ${expectedTotalCount}"

  sleep 10s
  while [[ $totalCount -lt $expectedTotalCount ]]
  do
    totalCount=0
    echo "Downloading required images.. please wait!"    
    for element in "${images[@]}"
    do
      case "$element" in
        *triton*)
            isDownloaded=$(oc describe pod -l app=image-downloader|grep "Successfully pulled image \"${TRITON_SERVER}\""|wc -l)
            existImage=$(oc describe pod -l app=image-downloader|grep "Container image \"${TRITON_SERVER}\" already present on machine"|wc -l)
            if [[ ${isDownloaded} != 0 || ${existImage} != 0 ]]; then
                triton_server_count=$(( ${isDownloaded} + ${existImage} ))
                totalCount=$((totalCount + ${triton_server_count}))
                echo "triton-server-count count: ${triton_server_count} - ${element}"
            fi 
            ;;
        *model_server*)
            isDownloaded=$(oc describe pod -l app=image-downloader|grep "Successfully pulled image \"${OPENVINO}\""|wc -l)
            existImage=$(oc describe pod -l app=image-downloader|grep "Container image \"${OPENVINO}\" already present on machine"|wc -l)
            if [[ ${isDownloaded} != 0 || ${existImage} != 0 ]]; then
                openvino_count=$(( ${isDownloaded} + ${existImage} ))
                totalCount=$((totalCount + ${openvino_count}))
                echo "openvino downloaded: ${openvino_count} - ${element}"
            fi
            ;;

        *mlserver*)
            isDownloaded=$(oc describe pod -l app=image-downloader|grep "Successfully pulled image \"${ML_SERVER}\""|wc -l)
            existImage=$(oc describe pod -l app=image-downloader|grep "Container image \"${ML_SERVER}\" already present on machine"|wc -l)
            if [[ ${isDownloaded} != 0 || ${existImage} != 0 ]]; then
                ml_server_count=$(( ${isDownloaded} + ${existImage} ))
                totalCount=$((totalCount + ${ml_server_count} ))
                echo "ml-server downloaded: ${ml_server_count} - ${element}"
            fi
            ;;

        *torchserve*)
            isDownloaded=$(oc describe pod -l app=image-downloader|grep "Successfully pulled image \"${TORCHSERVE}\""|wc -l)
            existImage=$(oc describe pod -l app=image-downloader|grep "Container image \"${TORCHSERVE}\" already present on machine"|wc -l)
            if [[ ${isDownloaded} != 0 || ${existImage} != 0 ]]; then
                torchserve_count=$(( ${isDownloaded} + ${existImage} ))
                totalCount=$((totalCount + ${torchserve_count} ))
                echo "torchserve downloaded: ${torchserve_count} - ${element}"
            fi
            ;;

        *modelmesh:*)
            isDownloaded=$(oc describe pod -l app=image-downloader|grep "Successfully pulled image \"${MODELMESH}\""|wc -l)
            existImage=$(oc describe pod -l app=image-downloader|grep "Container image \"${MODELMESH}\" already present on machine"|wc -l)
            if [[ ${isDownloaded} != 0 || ${existImage} != 0 ]]; then
                modelmesh_count=$(( ${isDownloaded} + ${existImage} ))
                totalCount=$((totalCount + ${modelmesh_count}))
                echo "modelmesh downloaded: ${modelmesh_count} - ${element}"
            fi
            ;;

        *modelmesh-runtime*)
            isDownloaded=$(oc describe pod -l app=image-downloader|grep "Successfully pulled image \"${MODELMESH_RUNTIME}\""|wc -l)
            existImage=$(oc describe pod -l app=image-downloader|grep "Container image \"${MODELMESH_RUNTIME}\" already present on machine"|wc -l)
            if [[ ${isDownloaded} != 0 || ${existImage} != 0 ]]; then
                modlemesh_runtime_count=$(( ${isDownloaded} + ${existImage} ))
                totalCount=$((totalCount + ${modlemesh_runtime_count} ))
                echo "modelmesh-runtime downloaded: ${modlemesh_runtime_count} - ${element}"
            fi
            ;;

        *rest-proxy*)
            isDownloaded=$(oc describe pod -l app=image-downloader|grep "Successfully pulled image \"${REST_PROXY}\""|wc -l)
            existImage=$(oc describe pod -l app=image-downloader|grep "Container image \"${REST_PROXY}\" already present on machine"|wc -l)
            if [[ ${isDownloaded} != 0 || ${existImage} != 0 ]]; then
                rest_proxy_count=$(( ${isDownloaded} + ${existImage} ))
                totalCount=$((totalCount + ${rest_proxy_count} ))
                echo "rest-proxy downloaded: ${rest_proxy_count} - ${element}"
            fi
            ;;
        *)
		      echo "Not expected images(${element})"
          exit 1
          ;;
      esac
    done

    # echo "2- $totalCount"
    # echo "3- $expectedTotalCount"
    # echo "4- $retries"
    # echo "5- $max_retries"
    if [[ $totalCount -lt $expectedTotalCount ]]; then
      if [[ ${retries} -lt ${max_retries} ]]; then
        echo 
        retries=$((retries + 1 ))
        echo "Reset totalCount = 0 and checking it again after 60s"
        sleep 60s
      else 
        echo "[INFO] Exceed max retries(${max_retries}) to downloaded so it will move on next step"
        break
      fi
    else
      echo "[SUCCESS] Downloaded necessary images on all nodes"
    fi
  done
}
cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: image-downloader
spec:
  selector:
    matchLabels:
      app: image-downloader
  template:
    metadata:
      labels:
        app: image-downloader
    spec:
      containers:
      - name: triton-image-downloader
        image: ${TRITON_SERVER}
        command: ["/bin/sh"]
        args: ["-c", "sleep infinity"]
      - name: mlserver-image-downloader
        image: ${ML_SERVER}
        command: ["/bin/sh"]
        args: ["-c", "sleep infinity"]
      - name: openvino-image-downloader
        image: ${OPENVINO}
        command: ["/bin/sh"]
        args: ["-c", "sleep infinity"]
      - name: torchserve-image-downloader
        image: ${TORCHSERVE}
        command: ["/bin/sh"]
        args: ["-c", "sleep infinity"]
      - name: modelmesh-image-downloader
        image: ${MODELMESH}
        command: ["/bin/sh"]
        args: ["-c", "sleep infinity"]
      - name: modelmesh-runtime-image-downloader
        image: ${MODELMESH_RUNTIME}
        command: ["/bin/sh"]
        args: ["-c", "sleep infinity"]
      - name: rest-proxy-image-downloader
        image: ${REST_PROXY}
        command: ["/bin/sh"]
        args: ["-c", "sleep infinity"]
EOF

wait_downloading_images

echo 
echo "Delete image downloading daemonset"
oc delete daemonset  image-downloader --force --grace-period=0
