import type { AdminPlayerProfile, PlayerSport } from '../players.api'

/** One sport as `GET /api/v1/admin/players/{id}` returns it; override what the test is about. */
export const playerSport = (overrides: Partial<PlayerSport> = {}): PlayerSport => ({
  sportId: 's-tennis',
  sportCode: 'tennis',
  level: 'Intermediate',
  levelName: 'متوسط',
  levelDescription: 'رالی‌های طولانی و سرویس مطمئن',
  experience: 'OneToThreeYears',
  formats: ['Singles', 'Doubles'],
  goals: ['FriendlyMatch', 'Fitness'],
  ...overrides,
})

/** A profile as `GET /api/v1/admin/players/{id}` returns it. */
export const playerProfile = (overrides: Partial<AdminPlayerProfile> = {}): AdminPlayerProfile => ({
  userId: 'u-1',
  displayName: 'سارا محمدی',
  photoUrl: '/media/avatars/u-1.jpg',
  gender: 'Female',
  birthDate: '1375/05/10',
  ageRange: '25-34',
  city: { id: 1, name: 'تهران' },
  bio: 'عصرها در باشگاه انقلاب بازی می‌کنم.',
  visibility: 'SameGender',
  status: 'Active',
  sports: [playerSport()],
  homeVenues: [{ id: 'v-1', name: 'باشگاه انقلاب' }],
  ...overrides,
})
