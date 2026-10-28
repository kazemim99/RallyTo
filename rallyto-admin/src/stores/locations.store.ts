import { defineStore } from 'pinia'
import { ref } from 'vue'
import { locationsApi, type City, type Province } from '../api/locations.api'

/**
 * Provinces and their cities, cached for the session: they are seeded reference data that does not change while
 * the panel is open. Each list is requested once; concurrent callers share the request, and a failed request is
 * forgotten so the next call tries again.
 */
export const useLocationsStore = defineStore('locations', () => {
  const provinces = ref<Province[]>([])
  /** Cities by province id, filled as provinces are opened. */
  const cities = ref<Record<number, City[]>>({})

  let provincesRequest: Promise<Province[]> | null = null
  const cityRequests = new Map<number, Promise<City[]>>()

  function loadProvinces(): Promise<Province[]> {
    provincesRequest ??= locationsApi.provinces().then(
      (list) => {
        provinces.value = list
        return list
      },
      (failure: unknown) => {
        provincesRequest = null
        throw failure
      },
    )
    return provincesRequest
  }

  function loadCities(provinceId: number): Promise<City[]> {
    let request = cityRequests.get(provinceId)
    if (!request) {
      request = locationsApi.cities(provinceId).then(
        (list) => {
          cities.value = { ...cities.value, [provinceId]: list }
          return list
        },
        (failure: unknown) => {
          cityRequests.delete(provinceId)
          throw failure
        },
      )
      cityRequests.set(provinceId, request)
    }
    return request
  }

  const citiesOf = (provinceId: number | null | undefined): City[] => (provinceId ? (cities.value[provinceId] ?? []) : [])

  /** The name of a city already loaded, or undefined. */
  function cityName(cityId: number | null | undefined): string | undefined {
    if (!cityId) return undefined
    for (const list of Object.values(cities.value)) {
      const found = list.find((city) => city.id === cityId)
      if (found) return found.name
    }
    return undefined
  }

  return { provinces, cities, loadProvinces, loadCities, citiesOf, cityName }
})
