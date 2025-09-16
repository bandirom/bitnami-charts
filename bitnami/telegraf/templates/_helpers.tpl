{{/*
Copyright Broadcom, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/*
Return the proper  image name
*/}}
{{- define "telegraf.image" -}}
{{ include "common.images.image" (dict "imageRoot" .Values.image "global" .Values.global) }}
{{- end -}}


{{/*
Create the name of the service account to use
*/}}
{{- define "telegraf.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "common.names.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Name of the Telegraf (TM) ConfigMap
*/}}
{{- define "telegraf.configmapName" -}}
{{- if .Values.existingConfigmap -}}
    {{- include "common.tplvalues.render" (dict "value" .Values.existingConfigmap "context" $) -}}
{{- else -}}
    {{- include "common.names.fullname" . -}}
{{- end -}}
{{- end -}}


{{/*
Return the proper Docker Image Registry Secret Names
*/}}
{{- define "telegraf.imagePullSecrets" -}}
{{- include "common.images.renderPullSecrets" (dict "images" (list .Values.image) "context" $) -}}
{{- end -}}


{{/*
Checks if any ports are configured to be exposed on the Telegraf (TM) service
*/}}
{{- define "telegraf.service.exposePorts" -}}
{{- if or .Values.service.exposeCiscoTelemetry .Values.service.exposeHealth .Values.service.exposeHttp .Values.service.exposeHttpV2 .Values.service.exposeInfluxdb .Values.service.exposeInfluxdbV2 .Values.service.exposeOtlpGrpc .Values.service.exposeOtlpHttp .Values.service.exposePrometheus .Values.service.exposeSocket .Values.service.exposeStatsd .Values.service.exposeSyslog .Values.service.exposeTcp .Values.service.exposeUdp .Values.service.exposeWebhooks .Values.service.extraPorts }}
true
{{- end }}
{{- end -}}

{{/*
  CUSTOM TEMPLATES: This section contains templates that make up the different parts of the telegraf configuration file.
  Ref: https://github.com/influxdata/helm-charts/blob/master/charts/telegraf/templates/_helpers.tpl
*/}}

{{- define "telegraf.config.global_tags" -}}
{{- if . -}}
[global_tags]
  {{- range $key, $val := . }}
      {{ $key }} = {{ $val | quote }}
  {{- end }}
{{- end }}
{{- end -}}

{{- define "telegraf.config.agent" -}}
{{- if . -}}
[agent]
{{- range $key, $value := . -}}
  {{- $tp := typeOf $value }}
  {{- if eq $tp "string"}}
      {{ $key }} = {{ $value | quote }}
  {{- end }}
  {{- if eq $tp "float64"}}
      {{ $key }} = {{ $value | int64 }}
  {{- end }}
  {{- if eq $tp "int"}}
      {{ $key }} = {{ $value | int64 }}
  {{- end }}
  {{- if eq $tp "bool"}}
      {{ $key }} = {{ $value }}
  {{- end }}
{{- end }}
{{- end }}
{{- end -}}

{{- define "telegraf.config.processors" -}}
  {{ include "telegraf.config.section" (list "processors" .) }}
{{- end -}}

{{- define "telegraf.config.aggregators" -}}
  {{ include "telegraf.config.section" (list "aggregators" .) }}
{{- end -}}

{{- define "telegraf.config.inputs" -}}
  {{ include "telegraf.config.section" (list "inputs" .) }}
{{- end -}}

{{- define "telegraf.config.outputs" -}}
  {{ include "telegraf.config.section" (list "outputs" .) }}
{{- end -}}

{{- define "telegraf.config.section" -}}
{{- $name := index . 0 -}}
{{- with index . 1 -}}
{{- range $itemIdx, $configObject := . -}}
    {{- range $item, $config := . }}
    [[{{ $name }}.{{- $item }}]]
    {{- if $config -}}
    {{- $tp := typeOf $config -}}
    {{- if eq $tp "map[string]interface {}" -}}
      {{- $args := dict "key" $item "value" $config "level" 1 "type" $name -}}
      {{ include "telegraf.config.any.table" $args }}
    {{- end }}
    {{- end }}
    {{ end }}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Renders indented table.
*/}}

{{- define "telegraf.config.any.table" -}}
{{- $n := (mul .level 2) | add 2 | int }}
{{- $args := dict "key" .key "value" .value "type" .type -}}
{{- include "telegraf.config.any.table.raw" $args | indent $n }}
{{- end }}

{{/*
Renders a table.
Renders primitive and arrays of primitive types first, then nested tables and arrays of nested tables.
*/}}

{{- define "telegraf.config.any.table.raw" -}}
{{- $key := .key }}
{{- $type := .type }}
{{- range $k, $v := .value }}
  {{- $tps := typeOf $v }}
  {{- if eq $tps "string" }}
  {{ $k }} = {{ $v | quote }}
  {{- else if eq $tps "float64" }}
    {{- $rv := float64 (int64 $v) }}
    {{- if eq $rv $v }}
  {{ $k }} = {{ $v | int64 }}
    {{- else }}
  {{ $k }} = {{ $v }}
    {{- end }}
  {{- else if eq $tps "int64" }}
  {{ $k }} = {{ $v }}
  {{- else if eq $tps "bool" }}
  {{ $k }} = {{ $v }}
  {{- else if eq $tps "[]interface {}" }}
    {{- if ne (index $v 0 | typeOf) "map[string]interface {}" }}
  {{ $k }} = [
      {{- $numOut := len $v }}
      {{- $numOut := sub $numOut 1 }}
      {{- range $b, $xv := $v }}
        {{- $i := int64 $b }}
        {{- $xtps := typeOf $xv }}
        {{- if eq $xtps "string" }}
    {{ $xv | quote }}
        {{- else if eq $xtps "float64" }}
          {{- $rxv := float64 (int64 $xv) }}
          {{- if eq $rxv $xv }}
            {{- if eq $k "percentiles" }}
    {{ $xv | int64 }}.0
            {{- else }}
    {{ $xv | int64 }}
            {{- end }}
          {{- else }}
    {{ $xv }}
          {{- end }}
        {{- else if eq $xtps "int64" }}
    {{ $xv }}
        {{- end }}
        {{- if ne $i $numOut -}}
        ,
        {{- end -}}
      {{- end }}
  ]
    {{- end }}
  {{- end }}
{{- end }}
{{- range $k, $v := .value }}
  {{- $tps := typeOf $v }}
  {{- if eq $tps "map[string]interface {}" }}
      {{- $args := dict "key" (printf "%s.%s" $key $k) "value" $v "type" $type }}
      {{- /* hack for existing incorrect mapping in values.yaml */ -}}
      {{- if eq "processors.enum.mapping" (printf "%s.%s" $type $args.key) }}
  [[{{ $type }}.{{ $args.key }}]]
      {{- else }}
  [{{ $type }}.{{ $args.key }}]
      {{- end }}
      {{- include "telegraf.config.any.table" $args -}}
  {{- else if eq $tps "[]interface {}" }}
    {{- if eq (index $v 0 | typeOf) "map[string]interface {}" }}
      {{- range $b, $xv := $v }}
        {{- $args := dict "key" (printf "%s.%s" $key $k) "value" $xv  "type" $type }}
  [[{{ $type }}.{{ $args.key }}]]
        {{- include "telegraf.config.any.table" $args -}}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}