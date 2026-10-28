<template>
  <img class="brand-mark" :src="appIcon" :width="size" :height="size" alt="" aria-hidden="true" />
</template>

<script setup lang="ts">
// The Rallyto app icon (the rally loop on the court-green tile), copied from branding/appicon.svg by
// branding/build_brand.py — never edited here. Decorative: the panel's name is always spelled out next to it.
import appIcon from '../../assets/brand/appicon.svg'

withDefaults(defineProps<{ size?: number }>(), { size: 32 })
</script>

<style scoped>
.brand-mark {
  display: block;
  flex-shrink: 0;
}
</style>
