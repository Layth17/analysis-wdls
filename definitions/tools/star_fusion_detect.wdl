version 1.0

task starFusionDetect {
  input {
    File star_fusion_genome_dir_zip
    # File junction_file
    String fusion_output_dir = "STAR-Fusion_outdir"
    String star_path = "/usr/local/bin/STAR"
    # TODO: is this presence or =true ?
    Boolean examine_coding_effect = false
    String? fusioninspector_mode  # enum [inspect, validate]
    Array[File] fastq
    Array[File] fastq2
    Array[String] outsam_attrrg_line
  }

  Int cores = 12
  Float zip_size = size(star_fusion_genome_dir_zip, "GB")
  Float fastq_size = size(flatten([fastq, fastq2]), "GB")
  Float junction_size = size(junction_file, "GB")
  Int space_needed_gb = 10 + round(2 * (zip_size + fastq_size + junction_size))
  runtime {
    memory: "64GB"
    cpu: cores
    docker: "trinityctat/starfusion:pre-1.11.c"
    disks: "local-disk ~{space_needed_gb} HDD"
  }

    # https://github.com/STAR-Fusion/STAR-Fusion/issues/175#issuecomment-567913451
  String genome_lib_dir = "`pwd`/" + basename(star_fusion_genome_dir_zip, ".zip")
  command <<<
    mkdir ~{genome_lib_dir} && unzip -qq ~{star_fusion_genome_dir_zip} -d ~{genome_lib_dir}
    /usr/local/src/STAR-Fusion/STAR-Fusion --CPU ~{cores} \
        --genome_lib_dir ~{genome_lib_dir} \
        # -J ~{junction_file} \
        --output_dir ~{fusion_output_dir} --STAR_PATH ~{star_path} \
        ~{true="--examine_coding_effect" false="" examine_coding_effect} \
        ~{if defined(fusioninspector_mode) then "--FusionInspector " + fusioninspector_mode else ""} \
        --STAR_outSAMattrRGline ~{sep=" , " outsam_attrrg_line} \
        --left_fq ~{sep="," fastq} --right_fq ~{sep="," fastq2}
  >>>

  output {
    # star fusion outputs 
    File fusion_predictions = fusion_output_dir + "/star-fusion.fusion_predictions.tsv"
    File fusion_abridged = fusion_output_dir + "/star-fusion.fusion_predictions.abridged.tsv"
    File? coding_region_effects = fusion_output_dir + "/star-fusion.fusion_predictions.abridged.coding_effect.tsv"
    # Fusion inspector outputs
    # if no mode specified, this will just not find any files
    Array[File] fusioninspector_evidence = glob(fusion_output_dir + "/FusionInspector-" + select_first([fusioninspector_mode, ""]) + "/finspector.*")
    File fusioninspector_log = fusion_output_dir + "/FusionInspector.log"
    # STAR alignment files
    File aligned_bam = fusion_output_dir + "/Aligned.out.bam"
    File log_final = fusion_output_dir + "/Log.final.out"
    File log = fusion_output_dir + "/Log.out"
    File log_progress = fusion_output_dir + "/Log.progress.out"
    File splice_junction_out = fusion_output_dir + "/SJ.out.tab"
    File chim_junc = fusion_output_dir + "/Chimeric.out.junction"
    # STAR also outputs gene counts file just like Kallisto
    File gene_counts = fusion_output_dir + "/ReadsPerGene.out.tab"
  }
}

workflow wf {
  input {
    File star_fusion_genome_dir_zip
    File junction_file
    String? fusion_output_dir
    String? star_path
    Boolean? examine_coding_effect
    String fusioninspector_mode  # enum [inspect, validate]
    Array[File] fastq
    Array[File] fastq2
    Array[String] outsam_attrrg_line
  }

  call starFusionDetect {
    input:
    star_fusion_genome_dir_zip=star_fusion_genome_dir_zip,
    junction_file=junction_file,
    fusion_output_dir=fusion_output_dir,
    star_path=star_path,
    examine_coding_effect=examine_coding_effect,
    fusioninspector_mode=fusioninspector_mode,
    fastq=fastq,
    fastq2=fastq2,
    outsam_attrrg_line=outsam_attrrg_line
  }
}
