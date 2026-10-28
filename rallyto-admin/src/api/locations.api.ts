import apiClient from '../utils/axios'

/** Iran's provinces and cities (catalog › locations): seeded reference data with stable ids. Any signed-in user. */

export interface Province {
  id: number
  name: string
}

export interface City {
  id: number
  provinceId: number
  name: string
  /** Visible clubs in the city. */
  activeVenueCount: number
}

export const PROVINCES_ENDPOINT = '/api/v1/provinces'

export const locationsApi = {
  async provinces(): Promise<Province[]> {
    const { data } = await apiClient.get<Province[]>(PROVINCES_ENDPOINT)
    return data ?? []
  },

  async cities(provinceId: number): Promise<City[]> {
    const { data } = await apiClient.get<City[]>(`${PROVINCES_ENDPOINT}/${encodeURIComponent(provinceId)}/cities`)
    return data ?? []
  },
}
