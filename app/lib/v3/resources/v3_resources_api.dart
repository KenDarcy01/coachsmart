// Pathway reads for the Resources page (same tables as
// webviews/games-resource-v2.html): club_pathway_link -> pathway_types,
// pathway_stages, pathway_stage_details (+ event_codes for the code).
import '/backend/supabase/supabase.dart';
import 'v3_resources_models.dart';

class V3ResourcesApi {
  const V3ResourcesApi();

  Future<List<Pathway>> pathways(int clubId) async =>
      parsePathways(await SupaFlow.client
          .from('club_pathway_link')
          .select('pathway_types(pathway_type_id, pathway_name)')
          .eq('club_id', clubId));

  Future<List<PathwayStage>> stages(int pathwayTypeId) async =>
      parseStages(await SupaFlow.client
          .from('pathway_stages')
          .select('pathway_stage_id, pathway_stage, pathway_stage_desc, '
              'pathway_ages, pathway_display_seq')
          .eq('pathway_type_id', pathwayTypeId)
          .order('pathway_display_seq', ascending: true));

  Future<List<StageDetail>> details(int stageId) async =>
      parseDetails(await SupaFlow.client
          .from('pathway_stage_details')
          .select('pathway_stage_details_id, detail_heading, '
              'detail_subheading, image_link, video_link, detail_code_id, '
              'detail_category, event_codes(event_code)')
          .eq('pathway_stage_id', stageId));
}

/// [V3ResourcesApi] from test data: {'pathways': [...], 'stages': [rows with
/// pathway_type_id], 'details': [rows with pathway_stage_id]}.
class V3OfflineResourcesApi extends V3ResourcesApi {
  const V3OfflineResourcesApi(this.data);
  final Map<String, dynamic> data;

  List<Map> _rows(String k) => [
        if (data[k] is List)
          for (final r in data[k] as List)
            if (r is Map) r
      ];

  @override
  Future<List<Pathway>> pathways(int clubId) async =>
      parsePathways(data['pathways']);

  @override
  Future<List<PathwayStage>> stages(int pathwayTypeId) async => parseStages([
        for (final r in _rows('stages'))
          if (r['pathway_type_id'] == pathwayTypeId) r
      ]);

  @override
  Future<List<StageDetail>> details(int stageId) async => parseDetails([
        for (final r in _rows('details'))
          if (r['pathway_stage_id'] == stageId) r
      ]);
}
