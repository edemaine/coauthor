import {Dynamic, render} from 'solid-js/web'

# Example usage from console:
# benchmark(require('/client/users.coffee').Users,{group:'test'})

window.benchmark = (component, props) ->
  times =
    for i in [1..51]  # eslint-disable-line coffee/no-unused-vars
      before = new Date
      dispose = render <Dynamic component={component} {...props}/>,
                       document.body
      after = new Date
      dispose()
      after - before
  total = 0
  total += time for time in times
  median = times[..].sort((x, y) -> x-y)[(times.length - 1)// 2]
  console.log "min=#{Math.min(...times)} mean=#{total / times.length} median=#{median} #{times.join ','}"
