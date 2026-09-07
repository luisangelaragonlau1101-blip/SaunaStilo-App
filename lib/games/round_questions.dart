import 'dart:math';
import '../academy/lesson_catalog.dart';

class ChoiceQuestion {
 final String text, answer, explanation, preview;
 final List<String> choices;
 const ChoiceQuestion(this.text,this.answer,this.choices,this.explanation,{this.preview=''});
 Map<String,dynamic> toJson()=>{'text':text,'answer':answer,'choices':choices,'explanation':explanation,'preview':preview};
 factory ChoiceQuestion.fromJson(Map<String,dynamic>d){
  final choices=List<String>.from(d['choices'] as List);
  if(choices.length!=4||choices.toSet().length!=4||!choices.contains(d['answer']))throw const FormatException('Opciones inválidas.');
  return ChoiceQuestion(d['text'] as String,d['answer'] as String,choices,d['explanation'] as String,preview:d['preview'] as String? ?? '');
 }
}
class RoundPack {
 final String id,title,description;
 const RoundPack(this.id,this.title,this.description);
}
const roundPacks=[
 RoundPack('riddles','Adivinanzas','Pistas breves para descubrir objetos y palabras.'),
 RoundPack('quiz','Quiz para todos','Preguntas sencillas para conversar y competir.'),
 RoundPack('addition','Suma relámpago','Suma dos números. Sin presión de tiempo.'),
 RoundPack('subtract','Resta perfecta','Encuentra lo que queda.'),
 RoundPack('multiply','Multiplica','Pequeños desafíos de las tablas.'),
 RoundPack('divide','Reparte y gana','Reparte cantidades en partes iguales.'),
 RoundPack('sequence','Sigue la serie','Descubre el patrón de los números.'),
 RoundPack('largest','El número mayor','Observa cuatro cantidades y elige la más grande.'),
 RoundPack('odd','El intruso','Encuentra el elemento que no pertenece al grupo.'),
 RoundPack('scramble','Palabras revueltas','Ordena mentalmente las letras.'),
 RoundPack('alphabet','Orden alfabético','¿Qué palabra aparece primero en el diccionario?'),
 RoundPack('count','Ojo de águila','Cuenta letras en una secuencia.'),
 RoundPack('clock','Reto del reloj','Avanza las horas en formato de 24 horas.'),
 RoundPack('change','Cambio exacto','Compras imaginarias y cálculos de cambio.'),
 RoundPack('english','Quiz de inglés','Reconoce palabras y frases básicas.'),
 RoundPack('french','Quiz de francés','Aprende vocabulario mientras juegas.'),
 RoundPack('flash','Memoria fugaz','Mira una secuencia, ocúltala y recuerda.'),
];
const riddleBank=<List<String>>[
 ['Tengo dientes, pero no como. Pongo en orden tu cabello.','Peine','Sus dientes separan y ordenan el cabello.'],
 ['Tengo teclas, pero no abro puertas. Conmigo escribes en la computadora.','Teclado','El teclado permite escribir.'],
 ['Tengo hojas, pero no soy árbol. Puedo contarte una historia.','Libro','Un libro tiene hojas y puede contener historias.'],
 ['Te sigo bajo la luz, pero no puedo abrazarte.','Sombra','La sombra cambia con la luz y tu posición.'],
 ['Voy en pareja y protejo tus pies al caminar.','Zapatos','Cada zapato cubre un pie.'],
 ['Tengo agujas que no cosen y te digo la hora.','Reloj','Las agujas de un reloj marcan horas y minutos.'],
 ['Cuanto más me usas para secarte, más mojada termino.','Toalla','La toalla absorbe el agua.'],
 ['Soy una caja fría que ayuda a conservar la comida.','Refrigerador','El refrigerador mantiene alimentos fríos.'],
 ['Tengo una punta y dejo letras de grafito en el papel.','Lápiz','El lápiz escribe con su mina.'],
 ['Puedo abrir una puerta, aunque soy mucho más pequeña que ella.','Llave','La llave acciona una cerradura.'],
 ['Guardo agua y tengo asa; puedes llevarme con una mano.','Cubeta','El asa permite transportar la cubeta.'],
 ['Soy transparente, estoy en una ventana y dejo pasar la luz.','Vidrio','El vidrio transparente permite ver a través.'],
 ['Mi nombre tiene cuatro letras: empieza con L y termina con A. Alumbró el cielo anoche.','Luna','L-U-N-A tiene cuatro letras.'],
 ['Soy un camino de peldaños para subir o bajar.','Escalera','Cada peldaño ayuda a cambiar de altura.'],
 ['Tengo cuello, pero no cabeza, y puedo guardar agua.','Botella','La parte estrecha superior se llama cuello.'],
 ['Tengo cuatro patas y un asiento, pero no camino.','Silla','Las patas sostienen la silla.'],
 ['Me abres cuando llueve para no mojarte desde arriba.','Paraguas','El paraguas desvía la lluvia.'],
 ['Repito tu voz cuando gritas en ciertos lugares.','Eco','El eco es un sonido reflejado.'],
 ['Soy una superficie donde ves tu reflejo al peinarte.','Espejo','El espejo refleja la luz.'],
 ['Me pones sobre una herida pequeña para cubrirla; tengo adhesivo.','Curita','La descripción corresponde a un apósito adhesivo.'],
 ['Tengo páginas con fechas y te ayudo a ubicar cada día.','Calendario','Un calendario organiza días y meses.'],
 ['Tengo cerdas y barro el suelo, pero no soy un animal.','Escoba','La escoba reúne polvo al barrer.'],
 ['Puedo tener tapa y guardar tus herramientas en el taller.','Caja','Una caja sirve para guardar objetos.'],
 ['Me aprietas para sujetar hojas; soy pequeño y de metal doblado.','Clip','Un clip sujeta hojas sin pegarlas.'],
];
const quizBank=<List<String>>[
 ['¿Cuántos lados tiene un triángulo?','3','Un triángulo tiene tres lados.'],
 ['¿Cuántos minutos tiene una hora?','60','Una hora contiene 60 minutos.'],
 ['¿Qué día sigue al lunes?','Martes','Lunes, martes, miércoles…'],
 ['¿Qué mes sigue a enero?','Febrero','Enero es el primer mes y febrero el segundo.'],
 ['¿Qué usamos para medir una longitud?','Regla','Una regla está marcada con unidades de longitud.'],
 ['¿Qué figura no tiene esquinas?','Círculo','La circunferencia de un círculo no tiene vértices.'],
 ['¿Cuántos meses tiene un año?','12','El calendario anual tiene doce meses.'],
 ['¿Qué instrumento tiene teclas y cuerdas?','Piano','El piano produce sonido al golpear cuerdas con martillos.'],
 ['¿Qué órgano usamos principalmente para ver?','Ojos','Los ojos captan la luz.'],
 ['¿Qué animal tiene una trompa larga?','Elefante','La trompa es característica del elefante.'],
 ['¿Cuál es el resultado de dos pares de guantes?','4 guantes','Cada par contiene dos guantes.'],
 ['¿Cuántos días tiene una semana?','7','Una semana va de lunes a domingo.'],
 ['¿Qué palabra nombra un color?','Verde','Verde es un color.'],
 ['¿Qué objeto sirve para borrar grafito?','Goma','La goma de borrar retira marcas de lápiz.'],
 ['¿Qué estación del año sigue al invierno?','Primavera','El ciclo continúa con la primavera.'],
 ['¿Cuál es la primera letra de SAUNA?','S','SAUNA comienza con S.'],
 ['¿Cuántas letras tiene STILO?','5','S-T-I-L-O: cinco letras.'],
 ['¿Qué símbolo indica una suma?','+','El signo más indica adición.'],
 ['¿Qué objeto se usa para tomar fotografías?','Cámara','Una cámara captura imágenes.'],
 ['¿Qué número viene antes del diez?','9','La secuencia es 8, 9, 10.'],
 ['¿Qué se pone en una carta para indicar el destinatario?','Dirección','La dirección indica adónde entregar la carta.'],
 ['¿Qué palabra tiene significado contrario a rápido?','Lento','Lento y rápido son opuestos.'],
 ['¿Qué palabra tiene significado contrario a abrir?','Cerrar','Abrir y cerrar describen acciones opuestas.'],
 ['¿Qué palabra se relaciona con escuchar?','Oído','El oído percibe sonidos.'],
];
const wordBank=['SAUNA','STILO','MADERA','EQUIPO','TALLER','PUERTA','VENTANA','BANCA','VAPOR','AGUA','LUZ','CASA','FLOR','LUNA','CAMINO','NUBE','MESA','SILLA','LIBRO','RELOJ','CAJA','LLAVE','MUNDO','AMIGO','JUEGO','NOTA','CANTO','PLAYA','BOSQUE','MANO'];
const oddBank=<List<String>>[
 ['Manzana','Pera','Uva','Martillo','Las primeras tres son frutas.'],
 ['Rojo','Verde','Amarillo','Silla','Los primeros tres son colores.'],
 ['Lunes','Martes','Jueves','Enero','Los primeros tres son días de la semana.'],
 ['Enero','Marzo','Julio','Domingo','Los primeros tres son meses.'],
 ['Perro','Gato','Conejo','Mesa','Los primeros tres son animales.'],
 ['Destornillador','Martillo','Serrucho','Manzana','Los primeros tres son herramientas.'],
 ['Triángulo','Cuadrado','Círculo','Zapato','Los primeros tres son figuras geométricas.'],
 ['Uno','Dos','Tres','Azul','Los primeros tres son números.'],
 ['Camisa','Pantalón','Abrigo','Taza','Los primeros tres son prendas.'],
 ['Ojo','Mano','Pie','Libro','Los primeros tres son partes del cuerpo.'],
 ['Piano','Guitarra','Violín','Cubeta','Los primeros tres son instrumentos musicales.'],
 ['Cuchara','Tenedor','Cuchillo','Calcetín','Los primeros tres son cubiertos.'],
];
ChoiceQuestion makeChoice(String text,String answer,Iterable<String> distractors,Random r,{String explanation='',String preview=''}){
 final rest=distractors.where((s)=>s!=answer).toSet().toList()..shuffle(r);
 if(rest.length<3)throw StateError('Se necesitan tres opciones distintas.');
 final options=[answer,...rest.take(3)]..shuffle(r);
 return ChoiceQuestion(text,answer,List.unmodifiable(options),explanation.isEmpty?'Respuesta: $answer.':explanation,preview:preview);
}
ChoiceQuestion _numeric(String text,int answer,Random r,{String explanation=''})=>makeChoice(text,'$answer',[for(int i=-9;i<=9;i++)'${answer+i}'],r,explanation:explanation);
ChoiceQuestion languageQuestion(StiloLesson lesson,int index,Random r){
 final pair=lesson.pairs[index%lesson.pairs.length],reverse=index>=lesson.pairs.length;
 return makeChoice(reverse?'¿Cómo se dice «${pair.spanish}» en ${lesson.languageName.toLowerCase()}?':'¿Qué significa «${pair.foreign}»?',reverse?pair.foreign:pair.spanish,
 lesson.pairs.map((p)=>reverse?p.foreign:p.spanish),r,explanation:'${pair.foreign} = ${pair.spanish}.');
}
ChoiceQuestion roundQuestion(String pack,Random r){
 int a=2+r.nextInt(30),b=2+r.nextInt(18);
 switch(pack){
  case 'riddles':final row=riddleBank[r.nextInt(riddleBank.length)];return makeChoice(row[0],row[1],riddleBank.map((e)=>e[1]),r,explanation:row[2]);
  case 'quiz':final row=quizBank[r.nextInt(quizBank.length)];return makeChoice(row[0],row[1],quizBank.map((e)=>e[1]),r,explanation:row[2]);
  case 'addition':return _numeric('$a + $b = ?',a+b,r,explanation:'$a + $b = ${a+b}.');
  case 'subtract':if(a<b){final t=a;a=b;b=t;}return _numeric('$a − $b = ?',a-b,r);
  case 'multiply':a=2+r.nextInt(11);b=2+r.nextInt(11);return _numeric('$a × $b = ?',a*b,r);
  case 'divide':a=2+r.nextInt(10);b=2+r.nextInt(10);return _numeric('Reparte ${a*b} fichas entre $a personas. ¿Cuántas recibe cada una?',b,r,explanation:'${a*b} ÷ $a = $b.');
  case 'sequence':b=2+r.nextInt(8);return _numeric('$a, ${a+b}, ${a+2*b}, ___',a+3*b,r,explanation:'Cada paso suma $b.');
  case 'largest':final values=<int>{};while(values.length<4){values.add(10+r.nextInt(990));}final answer=values.reduce(max);return makeChoice('¿Cuál de estas cantidades es mayor?','$answer',values.map((n)=>'$n'),r);
  case 'odd':final row=oddBank[r.nextInt(oddBank.length)];return makeChoice('¿Cuál es el intruso?',row[3],row.take(3),r,explanation:row[4]);
  case 'scramble':final answer=wordBank[r.nextInt(wordBank.length)],letters=answer.split('')..shuffle(r);if(letters.join()==answer){letters.add(letters.removeAt(0));}return makeChoice('Ordena estas letras: ${letters.join(' · ')}',answer,wordBank,r);
  case 'alphabet':final words=List<String>.of(wordBank)..shuffle(r);final selected=words.take(4).toList()..sort();return makeChoice('¿Qué palabra va primero en orden alfabético?',selected.first,selected,r);
  case 'count':final chars=List.generate(12,(_)=>['A','B','C','D'][r.nextInt(4)]),target=['A','B','C','D'][r.nextInt(4)];return _numeric('¿Cuántas $target hay?\n${chars.join('  ')}',chars.where((c)=>c==target).length,r);
  case 'clock':a=r.nextInt(24);b=1+r.nextInt(6);return makeChoice('Son las ${a.toString().padLeft(2,'0')}:00. ¿Qué hora será dentro de $b horas?', '${((a+b)%24).toString().padLeft(2,'0')}:00',[for(int n=0;n<24;n++)'${n.toString().padLeft(2,'0')}:00'],r,explanation:'Después de las 23:00 vuelve a empezar el día con las 00:00.');
  case 'change':a=1+r.nextInt(18);b=(a~/10+1)*10;return _numeric('Algo cuesta \$$a y pagas con \$$b. ¿Cuántos pesos recibes de cambio?',b-a,r,explanation:'$b − $a = ${b-a} pesos.');
  case 'english':case 'french':final lessons=stiloLessons.where((l)=>l.language==(pack=='english'?'en':'fr')).toList();final l=lessons[r.nextInt(lessons.length)];return languageQuestion(l,r.nextInt(12),r);
  case 'flash':final seq=List.generate(5,(_)=>wordBank[r.nextInt(10)]),pos=r.nextInt(5);return makeChoice('¿Qué palabra estaba en la posición ${pos+1}?',seq[pos],wordBank,r,preview:seq.join(' → '),explanation:'La secuencia era: ${seq.join(' → ')}.');
 }
 throw ArgumentError('Juego desconocido.');
}
