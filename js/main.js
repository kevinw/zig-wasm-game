    function startGame() {
        $webgl.width = window.innerWidth;
        $webgl.height = window.innerHeight;

        const env = {
          ...wasm,
          ...audio,
          ...zigdom,
          ...webgl,
        }

        fetchAndInstantiate('main_web.wasm', { env }).then(instance => {
          memory = instance.exports.memory;
          exports = instance.exports;

          exports.onInit($webgl.width, $webgl.height);

            document.addEventListener('keydown', e => {
                exports.onKeyDown(e.keyCode, 1, e.repeat);
                /*
                if (e.code == "KeyP") {
                    nextSavedEquation(-1);
                } else if (e.code == "KeyN") {
                    nextSavedEquation(1);
                }
                */
            });
          document.addEventListener('keyup', e => exports.onKeyUp(e.keyCode, 0));
          document.addEventListener('mousedown', e => exports.onMouseDown(e.button, e.x, e.y));
          document.addEventListener('mouseup', e => exports.onMouseUp(e.button, e.x, e.y));
          document.addEventListener('mousemove', e => exports.onMouseMove(e.x, e.y));
          document.addEventListener('resize', e => exports.onResize(e.width, e.height));

            const sendEq = () => {
              var res = copyBytesToWASM(eqInp.value);
              if (!res.success) {
                  console.error("error copying bytes to wasm");
                  return;
              }

              instance.exports.onEquation(res.ptr, res.len);
            };

          const eqInp = document.getElementById("equation-input");
          eqInp.addEventListener("keyup", function(e) {
              if (event.key === "Enter")
                  sendEq();
          });

          const onAnimationFrame = instance.exports.onAnimationFrame;
          function step(timestamp) {
            onAnimationFrame(timestamp);
            window.requestAnimationFrame(step);
          }
                const eqs = [
                    "(((((sin(A * 20 + time/14) + 2) * 30 + (cos(r * (20 + sin(A * 2 + time/41) * 5) + time/22) + 4) * 30) + (sin(x * time / y / 1000) + 2) * 5 - 20)*0x0000ff)&0x00ff00) + (((((sin(A * 20 + time/7) + 2) * 30 + (cos(r * (20 + sin(A * 2 + time/83) * 5) + time/11) + 4) * 30) + (sin(x * time / y / 1000) + 2) * 5 - 20)*1)&0x0000ff) + (((((sin(A * 20 + time/3.5) + 2) * 30 + (cos(r * (20 + sin(A * 2 + time/166) * 5) + time/6) + 4) * 30) + (sin(x * time / y / 1000) + 2) * 5 - 20)*0x00ff00)&0xff0000)",
                    "10  + 165 * sin(2.5+ (y-50) / 26 ) + 90*sin( time*0.7 - ((0.1*( x - 50 )^2 + (y-50)^2 )^0.45) ) - 255 * (1 + (((x-1) % 50) - (x % 50))) * (1 + (( (y+30-(time%18)-1) % 10) - ( (y+30-(time%18)) % 10))) * ((y%50) + (50-y)%50)",
                    "((time-x+y)|(time-y+x)|(time+x+y)|(time-x-y))^6", // TODO: why is this one so different? https://maxbittker.github.io/Mojulo/#KCh0aW1lLXgreSl8KHRpbWUteSt4KXwodGltZSt4K3kpfCh0aW1lLXgteSkpXjY=
                    "(y*x-(time*1))&(y+(cos(r*0.01*time)))",
                    "r*A*r*pow(sin(0.001*time)+(cos(0.01*time)+1),A)",
                    "cos(A*(r^x*4)*(sin(time*.01)+90))*(10000+pow(3,sin(time/15)))",
                     "(x-time)*pow(x, 0.001*x*y)",
                     "pow(r,2+cos(time*0.001))^((0.5*time)|(x*(sin(time*0.001)*10)))",
                     "-time^(time*.5)&(time*.3) -1000*(x^(time*.1))&100*(y^(time*.15))",
                     "(x*(time*sin(x*(time/900))*.1))-(y*(time*cos(y*time/1000)*.01))",
                    "((y*5-time*cos(x))^(x*5-time*cos(y)))^-(sin(time*.01)/tan(x)*cos(r)*y)",
                    ];

            var eqIndex = 0;
            function nextSavedEquation(delta) {
                if (delta === undefined) delta = 1;

                const eqToLoad = eqs[eqIndex];
                eqIndex += delta;
                if (eqIndex >= eqs.length) eqIndex = 0;
                else if (eqIndex < 0) eqIndex = eqs.length - 1;
                eqInp.value = eqToLoad;
                sendEq();
            }

          window.requestAnimationFrame(step);

        });
    }


    startGame();
