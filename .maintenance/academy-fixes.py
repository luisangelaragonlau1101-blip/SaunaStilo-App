from pathlib import Path

def replace(name, old, new):
    p = Path(name); text = p.read_text(); assert text.count(old) == 1, name + ': ' + old[:60]
    p.write_text(text.replace(old, new))

replace('lib/academy/learning_progress.dart', "   dates[lang]=raw.toSet().toList()..sort();", "   if ((d['days'] as Map).containsKey(lang)) dates[lang]=raw.toSet().toList()..sort();")
replace('lib/services/external_transfer.dart', 'ContextMenuButtonType.cut,ContextMenuButtonType.share]', 'ContextMenuButtonType.cut,ContextMenuButtonType.share,ContextMenuButtonType.searchWeb,ContextMenuButtonType.lookUp]')
replace('test/academy_arcade_test.dart', "final next=find.byKey(const ValueKey('round-next'));await tester.ensureVisible(next);", "final next=find.byKey(const ValueKey('round-next'));await tester.scrollUntilVisible(next,180,scrollable:find.byType(Scrollable).first);await tester.ensureVisible(next);")
replace('test/academy_arcade_test.dart', "final start=find.byKey(const ValueKey('lesson-practice'));await tester.ensureVisible(start);", "final start=find.byKey(const ValueKey('lesson-practice'));await tester.scrollUntilVisible(start,200,scrollable:find.byType(Scrollable).first);await tester.ensureVisible(start);")
helper = """ async function tap(target){
  await page.mouse.move(185,420);await page.mouse.wheel(0,-5000);await page.waitForTimeout(150);
  for(let n=0;n<18;n++){
   if(await target.count()){try{await target.click({timeout:1200});return;}catch(_){}}
   await page.mouse.wheel(0,260);await page.waitForTimeout(130);
  }
  throw Error('Target was not reachable through scrolling: '+target.toString());
 }
"""
p=Path('tools/academy-browser.cjs');s=p.read_text();s=s.replace(" async function frame(){",helper+" async function frame(){",1)
s=s.replace("await page.getByRole('button',{name:'Practicar · 12 ejercicios',exact:true}).click();", "await tap(page.getByRole('button',{name:'Practicar · 12 ejercicios',exact:true}));")
s=s.replace("await page.getByRole('button',{name:n===11?'Ver resultados':'Siguiente turno',exact:true}).click();", "await tap(page.getByRole('button',{name:n===11?'Ver resultados':'Siguiente turno',exact:true}));")
s=s.replace("await page.getByRole('button',{name:'Estoy listo',exact:true}).click();", "await tap(page.getByRole('button',{name:'Estoy listo',exact:true}));")
s=s.replace("await page.getByRole('button',{name:state.questions[n].answer,exact:true}).click();", "await tap(page.getByRole('button',{name:state.questions[n].answer,exact:true}));")
s=s.replace("await page.getByRole('button',{name:answer,exact:true}).click();", "await tap(page.getByRole('button',{name:answer,exact:true}));")
s=s.replace("await page.getByRole('button',{name:n===11?'Terminar lección':'Continuar',exact:true}).click();", "await tap(page.getByRole('button',{name:n===11?'Terminar lección':'Continuar',exact:true}));")
s=s.replace("    const text=await page.locator('body').innerText();", "    await page.mouse.move(185,420);await page.mouse.wheel(0,-5000);await page.waitForTimeout(150);\n    const text=await page.locator('body').innerText();")
s=s.replace("await page.getByText('120 XP total',{exact:true}).waitFor();", "await page.getByLabel('120 XP total',{exact:true}).waitFor();")
p.write_text(s)
