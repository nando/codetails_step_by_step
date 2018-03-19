center <<-EOS
  \e[1mstep by step\e[0m
 \e[1m──────────────────\e[0m
  a
  crontab
  paginated
  \e[1mEXPORTATION\e[0m

  @nando_chistaco
  ©TCK Codetails 2018
EOS

block <<-EOS
  Índice:
  \e[1m──────────────────────────────────────\e[0m
  Problema: \e[1mExportar participantes\e[0m___g+3
  Solución 1: \e[1mPetición síncrona\e[0m______g+9
  Solución 2: \e[1mSidekiq Job\e[0m___________g+15
  Solución 3: \e[1mRake task + crontab\e[0m___g+23
  Epílogo: \e[1mLa Programación\e[0m__________g+??
EOS

section "Problema: \e[1mExportar participantes\e[0m" do
  center <<-EOS
    \e[1mhttps://euro6000.com/champions-2018\e[0m
  EOS

  center <<-EOS
    \e[1mhttps://euro6000.com/admin/champions/participations\e[0m
  EOS

  block <<-EOS
    \e[1mModelo de datos\e[0m
    \e[1m────────────────────────────────────────────────────\e[0m
                    1  n
    Participaciones──────Predicciones/Aciertos/Ganadoras
                                        │1
                                        │
                              ┌─────────┘
                              │
             1           n    │1    1          2
    Jornadas───────────────Partidos──────────────Equipos
  EOS

  block <<-EOS
    Excel w. \e[1mzdavatz/spreadsheet\e[0m gem
    \e[1m─────────────────────────────────────────────\e[0m
    * Spreadsheet::Workbook#worksheets.first
    * Una participación por fila
    * Uso de \e[1mchampions/participation_presenter.rb\e[0m
  EOS
 
  center <<-EOS
    Instancio/iamos

    \e[1mmuchos objetos nuevos\e[0m

    para cada

    participación \e[1m(o acierto!!)\e[0m
  EOS
end

section "Solución 1: \e[1mPetición síncrona\e[0m" do

  center <<-EOS
    Exportar

    \e[1mcomo opción\e[0m

    del buscador
  EOS

  block <<-EOS
    \e[1mDos niveles:\e[0m
    \e[1m- Scopes:\e[0m
      * participations
      * hitters
      * prizewinners
    \e[1m- Filters:\e[0m
      * name/email
      * journey
      * team
      * prize
  EOS

  block <<-EOS
    En el modelo \e[1mChampions::Participation\e[0m:
    \e[1m─────────────────────────────────────────────\e[0m
    \e[1mscope :hitters\e[0m, lambda {
      joins( :predictions ).
      joins( :matches ).
      where( "champions_matches.final_result = 1" ).
      [ predictions&matches-ids-join ].
      [ equal-local-goals + equal-visiting-goals ].
      group( :email )
    }
    \e[1mscope :pricewinners\e[0m,
      -> { where prizewinner: true }
  EOS

  block <<-EOS
    En el controlador \e[1mParticipationsController\e[0m:
    \e[1m─────────────────────────────────────────────\e[0m
    include \e[1mParticipationsExporter\e[0m
    [...]
    def \e[1mexport\e[0m
      file_path = \e[1mgenerate_xls participations\e[0m
      [...]
    end
  EOS

  block <<-EOS
    En la librería \e[1mParticipationsExporter\e[0m:
    \e[1m─────────────────────────────────────────────\e[0m
    Spreadsheet\e[1m.open( local_filepath )
               .worksheets.first\e[0m

    presenters.each_with_index do | \e[31;1mp, row\e[0m |
      p.attribs.each_with_index do | \e[31;1mattrib, col\e[0m |
        sheet.row( \e[1mrow\e[0m )[ \e[1mcol\e[0m ] = \e[1mp\e[31;1m.send\e[0m(\e[1m attrib \e[0m)
      end
    end
  EOS
end

section "Solución 2: \e[1mSidekiq Job\e[0m" do
  block <<-EOS
    Máquina de estados: \e[1maasm\e[0m gem
    \e[1m────────────────────────────────────────────────────\e[0m

    class \e[1mAsyncExport < ActiveRecord::Base\e[0m
      include AASM
      validates \e[1m:scope\e[0m, presence: true
      serialize \e[1m:filter\e[0m
      [...]
      \e[1maasm\e[0m column: \e[31;1m:status\e[0m do
        [ states, events & transitions ]
      end
      [...]
    end
  EOS

  block <<-EOS
             ┌──────────────┐   init!       ┌───────────┐
             │\e[31;1msetting_filter\e[0m├─────────────> │\e[31;1minitialized\e[0m├─┐
             └──────────────┘   guard:      └───────────┘ │
                              summarized?                 │
                                                          │ export!
                ┌──────────┐  upload_to_s3!┌──────────┐   │
              ┌─┤ \e[31;1muploaded\e[0m │<──────────────┤ \e[31;1mexported\e[0m │<──┘
              │ └──────────┘               └──────────┘
              │
              │ finish!
              │
              ┴
            guard: \e[1ms3_obj.content_length == self.xls_file_size ?\e[0m
              ┬
              │                            ┌───────────┐
              └───────────────────────────>│ \e[31;1mfinished\e[0m!!│
                                           └───────────┘

  EOS

  block <<-EOS
    # DISCLAIMER: \e[1mOVER-SIMPLIFICATION\e[0m
    module Exporters
      class ChampionsParticipationsWorker
        \e[1minclude \e[31;1mSidekiq::Worker\e[31;0m

        def perform( \e[1masync_export_id\e[31;0m )
          async_export = AsyncExport.find( async_export_id )
          async_export\e[1m.init!\e[0m
          async_export\e[1m.export!\e[0m
          async_export\e[1m.upload_to_s3!\e[0m
          async_export\e[1m.finish!\e[0m
        end
      end
    end
  EOS

  block <<-EOS
    \e[1minit!\e[0m
    \e[1m────────────────────────────────────────────────────\e[0m
    event :init do
      transitions from: :setting_filter,
                  to: :initialized,
                  guard: :summarized? #\e[31;1m name & size\e[0m
    end                                    
  EOS

  block <<-EOS
    \e[1mexport!\e[0m
    \e[1m────────────────────────────────────────────────────\e[0m
     * Champions::Participation\e[1m.filter( scope, filter )\e[0m
     * Champions::\e[1mParticipationPresenter\e[0m.new participation
     * Spreadsheet::Workbook => book\e[31;1m.write local_filepath\e[0m
     * -> self.total_exported
     * -> self.xls_file_size
  EOS

  block <<-EOS
    \e[1mupload_to_s3!\e[0m
    \e[1m────────────────────────────────────────────────────\e[0m
      gem 'aws-sdk', \e[31;1m'~> 2.0'\e[0m # Shoryuken :(
      gem 'aws-sdk-v1'        # AWS::S3 => Aws::S3

       \e[1mAWS::S3\e[0m#buckets[ bucket ].
               create( \e[1ms3_filepath\e[0m, [...] ).
               tap do |obj|
                 obj.write( \e[1mfile: local_filepath\e[0m )
               end
  EOS

  block <<-EOS
    \e[1mfinish!\e[0m
    \e[1m────────────────────────────────────────────────────\e[0m
     * s3_obj.content_length == self.xls_file_size
     * Admin::Notification.create => \e[1m¡¡ TODO !!\e[0m
    
  EOS

end

section "Solución 3: \e[1mRake task + crontab\e[0m" do

  block <<-EOS
    \e[1mkaminari\e[0m to the rescue!!
    \e[1m────────────────────────────────────────────────────\e[0m
    Champions::Participation.filter( \e[1m:all\e[31;0m, @p_filter ).
                             \e[1mpage\e[0m( params[:page] ).
                             \e[1mper\e[0m( 10 )

    AsyncExport::\e[31;1mP12S_PER_BLOCK\e[0m => 250
  EOS

  block <<-EOS
    \e[1mcrontab\e[0m: our heartbeat!!
    \e[1m────────────────────────────────────────────────────\e[0m

    # config/schedule_batch.rb => \e[1mwhenever gem\e[0m
    \e[31;1mevery :minute\e[0m, roles: [ :batch, :staging ] do
      command "[..] \e[1mrake \e[31;1meuro6000:exports_step\e[0m"
    end
  EOS

  block <<-EOS
    \e[1meuro6000:exports_step rake task\e[0m: our pulse...
    \e[1m────────────────────────────────────────────────────\e[0m
    ¿¿ pending_export = \e[1mAsyncExport\e[31;1m.pending_export\e[0m ??

      if pending_export\e[1m.uploading?\e[0m
        pending_export\e[31;1m.finish!\e[0m
      else
        pending_export\e[31;1m.export_block!\e[0m
        if pending_export\e[1m.all_rows_exported?\e[0m
          pending_export\e[31;1m.upload!\e[0m
        end
      end

    Esto \e[1ma Rubocop no le mola\e[0m mucho...
  EOS

  center <<-EOS
    \e[1m¡¡ a mí tampoco !!\e[0m

    dominando más AASM
    se podría quitar
    mucha lógica de la
    tarea de rake
  EOS

  block <<-EOS
             ┌──────────────┐   init!       ┌───────────┐
             │\e[31;1msetting_filter\e[0m├─────────────> │\e[31;1minitialized\e[0m├─┐
             └──────────────┘   guard:      └───────────┘ │
                              summarized?                 │
                                             export_block!│
                                                          │
                ┌───────────┐ upload_to_s3!┌───────────┐  │
              ┌─┤ \e[31;1muploading\e[0m │<─────────────┤ \e[31;1mexporting\e[0m │<─┘
              │ └───────────┘              └─┬───────┬─┘
              │                              │       │
              │ finish!                      └───────┘
              │                            export_block!
              ┴
            guard: \e[1ms3_obj.content_length == self.xls_file_size ?\e[0m
              ┬
              │                            ┌───────────┐
              └───────────────────────────>│ \e[31;1mfinished\e[0m!!│
                                           └───────────┘

  EOS

end

section "Epílogo: La Programación" do

  block "LA PARTE MALA"
  block "Dependencia de MILES de piezas"
  block "LA PARTE BUENA"
  block "SIEMPRE hay (como poco!!) UNA solución"
  block "frecuencias gamma => \e[31;1mEUREKA!!\e[0m "

  center <<-EOS
    \e[1m¡GRACIAS!\e[0m
  EOS
end
