###
# Copyright 2013-2016  Zaid Abdulla
#
# GenieACS is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# GenieACS is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with GenieACS.  If not, see <http://www.gnu.org/licenses/>.
###

vm = require 'vm'
crypto = require 'crypto'

later = require 'later'

db = require './db'
query = require './query'


REFRESH = 3000

nextRefresh = 0
hash = null
presets = null
provisions = null
virtualParameters = null


UNLOCK_SCRIPT = 'if redis.call("get", KEYS[1]) == ARGV[1] then return redis.call("del", KEYS[1]) else return 0 end'
EXTEND_SCRIPT = 'if redis.call("get", KEYS[1]) == ARGV[1] then return redis.call("pexpire", KEYS[1], ARGV[2]) else return 0 end'

lock = (lockName, ttl, callback) ->
  token = Math.random().toString(36).slice(2)
  unlockOrExtend = (ttl) ->
    if not ttl
      db.redisClient.eval(UNLOCK_SCRIPT, 1, lockName, token, (err, res) ->
        throw err or new Error('Lock expired') if err or not res
      )
    else
      db.redisClient.eval(EXTEND_SCRIPT, 1, lockName, token, ttl, (err, res) ->
        throw err or new Error('Lock expired') if err or not res
      )
    return

  db.redisClient.set(lockName, token, 'NX', 'PX', ttl, (err, res) ->
    if err or res
      return callback(err, unlockOrExtend)

    setTimeout(() ->
      return lock(lockName, ttl, callback)
    , 200)
  )


computeHash = () ->
  # MD5 hash for presets, provisions, virtual parameters for detecting changes
  h = crypto.createHash('md5')
  for p in presets
    h.update(JSON.stringify(p.name))
    h.update(JSON.stringify(p.channel))
    h.update(JSON.stringify(p.schedule))
    h.update(JSON.stringify(p.events))
    h.update(JSON.stringify(p.precondition))
    h.update(JSON.stringify(p.provisions))

  keys = Object.keys(provisions).sort()
  h.update(JSON.stringify(keys))
  h.update(provisions[k].md5) for k in keys

  keys = Object.keys(virtualParameters).sort()
  h.update(JSON.stringify(keys))
  h.update(virtualParameters[k].md5) for k in keys

  hash = h.digest('hex')


refresh = (callback) ->
  now = Date.now()
  db.redisClient.get('presets_hash', (err, res) ->
    return callback(err) if err

    if hash? and res == hash
      nextRefresh = now + REFRESH
      return callback()

    lock('presets_hash_lock', 3000, (err, unlockOrExtend) ->
      counter = 3
      db.presetsCollection.find().toArray((err, res) ->
        if err
          callback(err) if -- counter >= 0
          counter = 0
          return

        res.sort((a, b) ->
          if a.weight == b.weight
            return a._id > b._id
          else
            return a.weight - b.weight
        )

        presets = []

        for preset in res
          schedule = null
          if preset.schedule
            parts = preset.schedule.trim().split(/\s+/)
            schedule = {
              md5: crypto.createHash('md5').update(preset.schedule).digest('hex')
            }

            try
              schedule.duration = +(parts.shift()) * 1000
              parts.unshift('0') if parts.length == 5
              # TODO later.js doesn't throw erorr if expression is invalid!
              schedule.schedule = later.schedule(later.parse.cron(parts.join(' '), true))
            catch err
              # TODO show a warning
              schedule.schedule = false

          events = preset.events ? {}

          precondition = query.convertMongoQueryToFilters(JSON.parse(preset.precondition))

          _provisions = preset.provisions or []

          # Generate provisions from the old configuration format
          for c in preset.configurations
            switch c.type
              when 'age'
                _provisions.push(['refresh', c.name, c.age * -1000])
              when 'value'
                _provisions.push(['value', c.name, c.value])
              when 'add_tag'
                _provisions.push(['tag', c.tag, true])
              when 'delete_tag'
                _provisions.push(['tag', c.tag, false])
              when 'provision'
                _provisions.push([c.name].concat(c.args or []))
              else
                throw new Error("Unknown configuration type #{c.type}")

          presets.push({name: preset._id, channel: preset.channel or 'default', schedule: schedule, events: events, precondition: precondition, provisions: _provisions})

        if -- counter == 0
          computeHash()
          db.redisClient.setex("presets_hash", 300, hash, (err) ->
            unlockOrExtend(0)
            nextRefresh = now + REFRESH
            return callback()
          )
      )

      db.provisionsCollection.find().toArray((err, res) ->
        if err
          callback(err) if -- counter >= 0
          counter = 0
          return

        provisions = {}
        for r in res
          provisions[r._id] = {}
          provisions[r._id].md5 = crypto.createHash('md5').update(r.script).digest('hex')
          provisions[r._id].script = new vm.Script(r.script, {filename: r._id, timeout: 50})

        if -- counter == 0
          computeHash()
          db.redisClient.setex("presets_hash", 300, hash, (err) ->
            unlockOrExtend(0)
            nextRefresh = now + REFRESH
            return callback()
          )
      )

      db.virtualParametersCollection.find().toArray((err, res) ->
        if err
          callback(err) if -- counter >= 0
          counter = 0
          return

        virtualParameters = {}
        for r in res
          virtualParameters[r._id] = {}
          virtualParameters[r._id].md5 = crypto.createHash('md5').update(r.script).digest('hex')
          virtualParameters[r._id].script = new vm.Script(r.script, {filename: r._id, timeout: 50})

        if -- counter == 0
          computeHash()
          db.redisClient.setex("presets_hash", 300, hash, (err) ->
            unlockOrExtend(0)
            nextRefresh = now + REFRESH
            return callback()
          )
      )
    )
  )



getPresets = (callback) ->
  if Date.now() < nextRefresh
    return callback(null, hash, presets)

  refresh((err) ->
    return callback(err, hash, presets)
  )


getProvisions = (callback) ->
  if Date.now() < nextRefresh
    return callback(null, hash, provisions)

  refresh((err) ->
    return callback(err, hash, provisions)
  )


getVirtualParameters = (callback) ->
  if Date.now() < nextRefresh
    return callback(null, hash, virtualParameters)

  refresh((err) ->
    return callback(err, hash, virtualParameters)
  )


getProvisionsAndVirtualParameters = (callback) ->
  if Date.now() < nextRefresh
    return callback(null, hash, provisions, virtualParameters)

  refresh((err) ->
    return callback(err, hash, provisions, virtualParameters)
  )

exports.getPresets = getPresets
exports.getProvisions = getProvisions
exports.getProvisionsAndVirtualParameters = getProvisionsAndVirtualParameters
