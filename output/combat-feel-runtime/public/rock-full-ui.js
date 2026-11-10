(()=>{
 const host=document.createElement("div");host.id="rock-review-controls";host.hidden=true;
 host.innerHTML=`<p><strong>岩鬃兽完整候选 · 待用户验收，未交正式接入</strong><br><small>以下按钮重设隔离训练起点，后续按真实战斗推进；不是预录动画。自然对打使用“重置双方”。咆哮使用主会话原气流图；冲撞烟尘按真实路径累计并保留最近90单位，停冲即清除。眩晕看星环，减速看贴身淡金下坠气流与头顶双下箭，到期淡出；只表示减速，不额外减伤；力竭看低伏喘息。体积碰撞为角色之间的脚底占位，地图通行仍沿用原脚点规则。</small></p><nav aria-label="岩鬃兽验收情境"><button data-rock="near">近距离咆哮</button><button data-rock="middle">中距离咆哮</button><button data-rock="far">远距离咆哮</button><button data-rock="miss">咆哮未命中</button><button data-rock="chain">四连起点</button></nav><div id="rock-live" role="status"></div>`;
 const bodyButton=document.createElement("button");bodyButton.dataset.rock="body";bodyButton.textContent="体积碰撞对照";host.querySelector("nav").append(bodyButton);
 for(const [kind,name] of [["open","空地短击飞"],["wall","障碍碰撞眩晕"],["edge","地图边缘眩晕"]]){const b=document.createElement("button");b.dataset.rock=kind;b.textContent=name;host.querySelector("nav").append(b);}
 for(const [kind,name] of [["water","池岸击飞不晕"],["roar_chain","音波接完整四连"]]){const b=document.createElement("button");b.dataset.rock=kind;b.textContent=name;host.querySelector("nav").append(b);}
 document.querySelector("#status").before(host);
 let serial=0;
 host.addEventListener("click",e=>{const kind=e.target.dataset.rock;if(!kind||window.editorTrainingStatus?.generation!==window.editorGeneration)return;window.rockScenarioCommand={id:++serial,scenario:kind};const frame=document.querySelector("#game");frame.contentWindow?.focus();frame.contentWindow?.document.querySelector("canvas")?.focus();});
 document.querySelector("#game").addEventListener("load",()=>{window.rockFullStatus=null;window.rockScenarioCommand=null;});
 const phases={active:"追击",lunge_charge:"冲撞蓄力",lunge:"冲撞",lunge_recover:"刹停收势",stunned:"撞晕·可反击",charge:"咆哮前摇",rush:"咆哮释放",rest:"力竭·可反击"};
 setInterval(()=>{host.hidden=window.runtimeEnemy!=="rockmane";const s=window.editorTrainingStatus?.generation===window.editorGeneration?window.rockFullStatus:null;host.querySelectorAll("button").forEach(b=>b.disabled=!s);document.querySelector("#rock-live").textContent=s?`${phases[s.phase]||s.phase} · 连段剩余 ${s.chain_left} · 玩家眩晕 ${s.stun_left.toFixed(1)}秒 · 减速 ${s.slow_left.toFixed(1)}秒 / 剩余速度 ${Math.round(s.slow_factor*100)}%${s.error?" · "+s.error:""}`:"正在加载完整候选…";},150);
})();
