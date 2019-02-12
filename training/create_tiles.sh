#!/bin/bash
ARGS="${@-./input}"

shopt -s extglob

INPUT_DIR=${ARGS}

MIN_TILE_WIDTH=64
MIN_TILE_HEIGHT=64

MAX_TILE_WIDTH=128
MAX_TILE_HEIGHT=128

# Examples
LR_SCALE=25%
LR_FILTER=point
LR_INTERPOLATE=Nearest
LR_OUTPUT_DIR=./output.lr

# Ground truth
HR_SCALE=100%
HR_FILTER=point
HR_INTERPOLATE=Nearest
HR_OUTPUT_DIR=./output.hr

mkdir -p "${LR_OUTPUT_DIR}"
mkdir -p "${HR_OUTPUT_DIR}"

find "${INPUT_DIR}" \( -iname "*.dds" -or -iname "*.png"  \) | while read FILENAME; do

  DIRNAME=$(dirname "${FILENAME}")
  BASENAME=$(basename "${FILENAME%.*}")
  ESCAPED_DIR=$(printf '%q' "${DIRNAME}")
  ESCAPED_FILE=$(printf '%q' "${FILENAME}")
  DIRNAME_HASH=$(echo ${DIRNAME} | md5sum | cut -d' ' -f1)

  if [ ! -f "${OUTPUT_DIR}/${DIRNAME_HASH}_${BASENAME}_000.png" ]; then

    IMAGE_WIDTH=$(identify -format '%[width]' "${FILENAME}")
    IMAGE_HEIGHT=$(identify -format '%[height]' "${FILENAME}")
    COLOR_TYPE=$(identify -format '%[channels]' "${FILENAME}")

    RELATIVE_DIR=$(realpath --relative-to "${INPUT_DIR}" "${DIRNAME}")

    if [ "$((${IMAGE_WIDTH}))" -ge "${MIN_TILE_WIDTH}" ] && [ "$((${IMAGE_HEIGHT}))" -ge "${MIN_TILE_HEIGHT}" ]; then

      VERTICAL_SUBDIVISIONS=$((${IMAGE_HEIGHT} / ${MAX_TILE_HEIGHT}))
      if [ "${VERTICAL_SUBDIVISIONS}" -lt "1" ]; then
        VERTICAL_SUBDIVISIONS=$((${IMAGE_HEIGHT} / ${MIN_TILE_HEIGHT}))
      fi
      HORIZONTAL_SUBDIVISIONS=$((${IMAGE_WIDTH} / ${MAX_TILE_WIDTH}))
      if [ "${HORIZONTAL_SUBDIVISIONS}" -lt "1" ]; then
        HORIZONTAL_SUBDIVISIONS=$((${IMAGE_WIDTH} / ${MIN_TILE_WIDTH}))
      fi

      if [ "$(convert "${FILENAME}" -alpha off -format "%[k]" info:)" -gt "1" ]; then
        echo ${FILENAME}, rgb \(${IMAGE_WIDTH}x${IMAGE_HEIGHT} divided by ${HORIZONTAL_SUBDIVISIONS}x${VERTICAL_SUBDIVISIONS}\)
        convert "${FILENAME}" -alpha off -crop ${HORIZONTAL_SUBDIVISIONS}x${VERTICAL_SUBDIVISIONS}@ +repage +adjoin -define png:color-type=2 -interpolate ${HR_INTERPOLATE} -filter ${HR_FILTER} -resize ${HR_SCALE} "${HR_OUTPUT_DIR}/${DIRNAME_HASH}_${BASENAME}_%03d.png"
        convert "${FILENAME}" -alpha off -crop ${HORIZONTAL_SUBDIVISIONS}x${VERTICAL_SUBDIVISIONS}@ +repage +adjoin -define png:color-type=2 -interpolate ${LR_INTERPOLATE} -filter ${LR_FILTER} -resize ${LR_SCALE} "${LR_OUTPUT_DIR}/${DIRNAME_HASH}_${BASENAME}_%03d.png"
      else
        echo ${FILENAME}, rgb single color, skipped
      fi
      if [ "${COLOR_TYPE}" == "rgba" ] || [ "${COLOR_TYPE}" == "srgba" ]; then
        if [ "$(convert "${FILENAME}" -alpha extract -format "%[k]" info:)" -gt "1" ]; then
          echo ${FILENAME}, alpha \(${IMAGE_WIDTH}x${IMAGE_HEIGHT} divided by ${HORIZONTAL_SUBDIVISIONS}x${VERTICAL_SUBDIVISIONS}\)
          convert "${FILENAME}" -alpha extract -crop ${HORIZONTAL_SUBDIVISIONS}x${VERTICAL_SUBDIVISIONS}@ +repage +adjoin -define png:color-type=2 -interpolate ${HR_INTERPOLATE} -filter ${HR_FILTER} -resize ${HR_SCALE} "${HR_OUTPUT_DIR}/${DIRNAME_HASH}_${BASENAME}_alpha_%03d.png"
          convert "${FILENAME}" -alpha extract -crop ${HORIZONTAL_SUBDIVISIONS}x${VERTICAL_SUBDIVISIONS}@ +repage +adjoin -define png:color-type=2 -interpolate ${LR_INTERPOLATE} -filter ${LR_FILTER} -resize ${LR_SCALE} "${LR_OUTPUT_DIR}/${DIRNAME_HASH}_${BASENAME}_alpha_%03d.png"
        else
          echo ${FILENAME}, alpha single color, skipped
        fi
      fi

    else
      echo ${FILENAME} too small \(${IMAGE_WIDTH}x${IMAGE_HEIGHT}\), skipped
    fi

  else
    echo ${FILENAME}, already processed, skipped
  fi

done
