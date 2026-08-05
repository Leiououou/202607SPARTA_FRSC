/* ----------------------------------------------------------------------
   SPARTA - Stochastic PArallel Rarefied-gas Time-accurate Analyzer
   http://sparta.github.io
   Steve Plimpton, sjplimp@gmail.com, Michael Gallis, magalli@sandia.gov
   Sandia National Laboratories

   Copyright (2014) Sandia Corporation.  Under the terms of Contract
   DE-AC04-94AL85000 with Sandia Corporation, the U.S. Government retains
   certain rights in this software.  This software is distributed under
   the GNU General Public License.

   See the README file in the top-level SPARTA directory.
------------------------------------------------------------------------- */

#include "math.h"
#include "stdlib.h"
#include "string.h"
#include "surf_react_gamma.h"
#include "input.h"
#include "update.h"
#include "comm.h"
#include "surf.h"
#include "domain.h"
#include "particle.h"
#include "surf_collide_diffuse.h"
#include "random_mars.h"
#include "random_knuth.h"
#include "memory.h"
#include "error.h"

using namespace SPARTA_NS;

enum{INT,DOUBLE};
enum{FACE,SURF};

#define MAXLINE 1024
#define DELTALIST 10
#define DELTA_TALLY 1024

/* ---------------------------------------------------------------------- */

SurfReactGamma::SurfReactGamma(SPARTA *sparta, int narg, char **arg) :
  SurfReact(sparta, narg, arg)
{
  if (surf->implicit)
    error->all(FLERR,"Cannot use surf_react gamma with implicit surfaces");

  if (narg < 5) error->all(FLERR,"Illegal surf_react gamma command");

  me = comm->me;
  nprocs = comm->nprocs;
  distributed = surf->distributed;

  // Backward-compatible forms:
  //   ID gamma file mode Tw nsite ...
  //   ID gamma only_one no  file mode Tw nsite ...
  //   ID gamma only_one yes file mode Tw ...

  only_one_flag = 0;
  int ibase = 2;
  if (strcmp(arg[ibase],"only_one") == 0) {
    if (narg < ibase+2)
      error->all(FLERR,"Illegal surf_react gamma command");
    if (strcmp(arg[ibase+1],"yes") == 0) only_one_flag = 1;
    else if (strcmp(arg[ibase+1],"no") == 0) only_one_flag = 0;
    else error->all(FLERR,"Illegal surf_react gamma only_one option");
    ibase += 2;
  }

  int nrequired = only_one_flag ? 3 : 4;
  if (narg < ibase+nrequired)
    error->all(FLERR,"Illegal surf_react gamma command");

  int file_index = ibase;
  int mode_index = ibase+1;
  int twall_index = ibase+2;
  int iarg = ibase+3;

  if (strcmp(arg[mode_index],"face") == 0) mode = FACE;
  else if (strcmp(arg[mode_index],"surf") == 0) mode = SURF;
  else error->all(FLERR,"Illegal surf_react gamma command");

  if (mode == SURF && surf->nsurf == 0)
    error->all(FLERR,"Cannot use surf_react gamma when no surfs exist");

  twall = input->numeric(FLERR,arg[twall_index]);
  nsite = 0.0;
  if (!only_one_flag) nsite = input->numeric(FLERR,arg[iarg++]);
  if (twall <= 0.0 || (!only_one_flag && nsite <= 0.0))
    error->all(FLERR,"Illegal surf_react gamma command");

  int nspecies = particle->nspecies;
  gamma_coeff = new double[nspecies];
  gamma_set = new int[nspecies];
  initial_set = new int[nspecies];
  for (int i = 0; i < nspecies; i++) {
    gamma_coeff[i] = 0.0;
    gamma_set[i] = 0;
    initial_set[i] = 0;
  }

  initial = NULL;
  ninitial = maxinitial = 0;
  tally_only_flag = 0;
  int tally_only_set = 0;
  double initial_sum = 0.0;

  while (iarg < narg) {
    if (strcmp(arg[iarg],"init_cover") == 0) {
      if (only_one_flag)
        error->all(FLERR,
                   "Cannot use surf_react gamma init_cover with only_one yes");
      if (iarg+2 >= narg)
        error->all(FLERR,"Illegal surf_react gamma command");

      int isp = particle->find_species(arg[iarg+1]);
      if (isp < 0)
        error->all(FLERR,"Surf_react gamma species is not defined");
      if (initial_set[isp])
        error->all(FLERR,"Duplicate surf_react gamma init_cover species");

      double fraction = input->numeric(FLERR,arg[iarg+2]);
      if (fraction < 0.0 || fraction > 1.0)
        error->all(FLERR,"Illegal surf_react gamma init_cover fraction");
      initial_sum += fraction;
      if (initial_sum > 1.0 + 1.0e-12)
        error->all(FLERR,"Surf_react gamma initial coverage exceeds one");

      if (ninitial == maxinitial) {
        maxinitial += DELTALIST;
        initial = (InitialCoverage *)
          memory->srealloc(initial,maxinitial*sizeof(InitialCoverage),
                           "surf_react/gamma:initial");
      }
      initial[ninitial].species = isp;
      initial[ninitial].fraction = fraction;
      ninitial++;
      initial_set[isp] = 1;
      iarg += 3;

    } else if (strcmp(arg[iarg],"tally_only") == 0) {
      if (iarg+1 >= narg || tally_only_set)
        error->all(FLERR,"Illegal surf_react gamma command");
      if (strcmp(arg[iarg+1],"yes") == 0) tally_only_flag = 1;
      else if (strcmp(arg[iarg+1],"no") == 0) tally_only_flag = 0;
      else error->all(FLERR,"Illegal surf_react gamma tally_only option");
      tally_only_set = 1;
      iarg += 2;

    } else {
      if (iarg+1 >= narg)
        error->all(FLERR,"Illegal surf_react gamma command");

      int isp = particle->find_species(arg[iarg]);
      if (isp < 0)
        error->all(FLERR,"Surf_react gamma species is not defined");
      if (gamma_set[isp])
        error->all(FLERR,"Duplicate surf_react gamma species");

      double value = input->numeric(FLERR,arg[iarg+1]);
      if (value < 0.0 || value > 1.0)
        error->all(FLERR,"Illegal surf_react gamma coefficient");
      gamma_coeff[isp] = value;
      gamma_set[isp] = 1;
      iarg += 2;
    }
  }

  rlist = NULL;
  nlist = maxlist = 0;
  reaction_map = NULL;
  readfile(arg[file_index]);
  if (nlist == 0)
    error->all(FLERR,"Surf_react gamma reaction file has no reactions");

  build_surface_species();
  build_reaction_map();

  nsingle = ntotal = 0;
  tally_single = new int[nlist];
  tally_total = new int[nlist];
  tally_single_all = new int[nlist];
  tally_total_all = new int[nlist];
  for (int i = 0; i < nlist; i++)
    tally_single[i] = tally_total[i] =
      tally_single_all[i] = tally_total_all[i] = 0;
  size_vector = 2 + 2*nlist;

  random = new RanKnuth(update->ranmaster->uniform());
  double seed = update->ranmaster->uniform();
  random->reset(seed,me,100);

  char *dargs[4];
  dargs[0] = (char *) "react_gamma";
  dargs[1] = (char *) "diffuse";
  dargs[2] = arg[twall_index];
  dargs[3] = (char *) "1.0";
  diffuse = new SurfCollideDiffuse(sparta,4,dargs);
  diffuse_coeffs[0] = twall;
  diffuse_coeffs[1] = 1.0;

  face_species_state = NULL;
  face_total_state = face_area = face_weight = NULL;
  face_species_delta = face_sum_delta = NULL;

  total_state_index = species_state_index = -1;
  area_index = weight_index = -1;
  total_state_name = custom_name("total");
  species_state_name = custom_name("species");
  area_name = custom_name("area");
  weight_name = custom_name("weight");

  surf_species_delta = NULL;
  mark = NULL;
  tally2surf = NULL;
  incollate = outcollate = NULL;
  maxtally = 0;

  species_state = NULL;
  total_state = area = weight = NULL;
  species_delta = NULL;

  one_state_win = MPI_WIN_NULL;
  one_state_owned = NULL;
  one_state_nown = 0;

  if (mode == FACE) create_per_face_state();
  else create_per_surf_state();

  firstflag = 1;
}

/* ---------------------------------------------------------------------- */

SurfReactGamma::~SurfReactGamma()
{
  if (copy) return;

  if (one_state_win != MPI_WIN_NULL) MPI_Win_free(&one_state_win);
  one_state_owned = NULL;

  delete random;
  delete diffuse;

  for (int i = 0; i < nlist; i++) {
    delete [] rlist[i].id;
    delete [] rlist[i].id_reactants[0];
    delete [] rlist[i].id_reactants[1];
    delete [] rlist[i].id_product;
  }
  memory->sfree(rlist);
  memory->destroy(reaction_map);

  delete [] gamma_coeff;
  delete [] gamma_set;
  delete [] initial_set;
  memory->sfree(initial);

  delete [] species_surf;
  delete [] species2surf;

  if (mode == FACE) {
    memory->destroy(face_species_state);
    memory->destroy(face_total_state);
    memory->destroy(face_area);
    memory->destroy(face_weight);
    memory->destroy(face_species_delta);
    memory->destroy(face_sum_delta);

  } else {
    int index = surf->find_custom(total_state_name);
    if (index >= 0) surf->remove_custom(index);
    index = surf->find_custom(species_state_name);
    if (index >= 0) surf->remove_custom(index);
    index = surf->find_custom(area_name);
    if (index >= 0) surf->remove_custom(index);
    index = surf->find_custom(weight_name);
    if (index >= 0) surf->remove_custom(index);

    memory->destroy(surf_species_delta);
    memory->destroy(mark);
    memory->destroy(tally2surf);
    memory->destroy(incollate);
    memory->destroy(outcollate);
  }

  delete [] total_state_name;
  delete [] species_state_name;
  delete [] area_name;
  delete [] weight_name;
}

/* ---------------------------------------------------------------------- */

void SurfReactGamma::init()
{
  SurfReact::init();
  diffuse->init();

  if (!firstflag) return;
  firstflag = 0;

  if (mode == FACE) initialize_cover_face();
  else initialize_per_surf_state();

  if (only_one_flag) create_one_state_window();

  if (me == 0) {
    if (screen)
      fprintf(screen,"  Wall chemistry model: constant-gamma\n");
    if (logfile)
      fprintf(logfile,"  Wall chemistry model: constant-gamma\n");
    if (screen) {
      if (only_one_flag)
        fprintf(screen,"  Site mode: one site per surface\n");
      else fprintf(screen,"  Site mode: nsite-based, nsite = %.8g\n",nsite);
    }
    if (logfile) {
      if (only_one_flag)
        fprintf(logfile,"  Site mode: one site per surface\n");
      else fprintf(logfile,"  Site mode: nsite-based, nsite = %.8g\n",nsite);
    }
    if (tally_only_flag) {
      if (screen) fprintf(screen,"  *** TALLY-ONLY mode: "
                          "reactions counted but NOT executed ***\n");
      if (logfile) fprintf(logfile,"  *** TALLY-ONLY mode: "
                           "reactions counted but NOT executed ***\n");
    }
    for (int i = 0; i < ninitial; i++) {
      const char *name = particle->species[initial[i].species].id;
      if (screen)
        fprintf(screen,"  Init_cover: %.6g%% sites filled with %s\n",
                initial[i].fraction*100.0,name);
      if (logfile)
        fprintf(logfile,"  Init_cover: %.6g%% sites filled with %s\n",
                initial[i].fraction*100.0,name);
    }
  }
}

/* ----------------------------------------------------------------------
   select and perform a constant-gamma gas/surface event
------------------------------------------------------------------------- */

int SurfReactGamma::react(Particle::OnePart *&ip, int isurf, double *norm,
                          Particle::OnePart *&jp, int &velreset)
{
  if (isurf < 0 && mode == SURF)
    error->one(FLERR,"Surf_react gamma surf used with box faces");
  if (isurf >= 0 && mode == FACE)
    error->one(FLERR,"Surf_react gamma face used with surface elements");

  if (mode == FACE) isurf = -(isurf+1);

  int incident = ip->ispecies;
  double gamma = gamma_coeff[incident];
  if (gamma <= 0.0 || random->uniform() >= gamma) return 0;

  int jsurf;
  int one_owner = -1;
  MPI_Aint one_disp = 0;

  // A one-site surface is a global state, not a per-rank cached count.
  // Hold an exclusive passive-target lock while reading and changing it so
  // simultaneous collisions on the same surf are serialized across ranks.

  if (only_one_flag) {
    int encoded = lock_one_state(isurf,one_owner,one_disp);
    if (encoded < 0 || encoded > particle->nspecies) {
      MPI_Win_unlock(one_owner,one_state_win);
      error->one(FLERR,"Invalid surf_react gamma one-site species");
    }
    jsurf = encoded ? species2surf[encoded-1] : -1;
    if (encoded && jsurf < 0) {
      MPI_Win_unlock(one_owner,one_state_win);
      error->one(FLERR,"Invalid surf_react gamma one-site species");
    }
  } else jsurf = select_surface_species(isurf);

  // vacant site: adsorption is a state transition, not a file reaction

  if (jsurf < 0) {
    if (tally_only_flag) {
      if (only_one_flag) MPI_Win_unlock(one_owner,one_state_win);
      return 0;
    }

    int iad = species2surf[incident];
    if (iad < 0) {
      if (only_one_flag) MPI_Win_unlock(one_owner,one_state_win);
      error->one(FLERR,"Surf_react gamma incident species cannot adsorb");
    }

    if (only_one_flag) {
      put_one_state(one_owner,one_disp,incident+1);
      MPI_Win_unlock(one_owner,one_state_win);
    } else {
      mark_surface(isurf);
      species_delta[isurf][iad]++;
    }
    ip = NULL;
    return 0;
  }

  // occupied site without a defined unordered reaction:
  // both the incident and adsorbed particles leave the surface separately

  int adsorbed = species_surf[jsurf];
  int ireaction = reaction_map[incident][adsorbed];
  if (ireaction < 0) {
    if (tally_only_flag) {
      if (only_one_flag) MPI_Win_unlock(one_owner,one_state_win);
      return 0;
    }

    if (only_one_flag) {
      put_one_state(one_owner,one_disp,0);
      MPI_Win_unlock(one_owner,one_state_win);
    } else {
      mark_surface(isurf);
      species_delta[isurf][jsurf]--;
    }

    // create the desorbed particle at the incident particle's collision point
    // add_particle() can reallocate the particle array, so repoint ip if needed

    double x[3],v[3];
    int pid = MAXSMALLINT*random->uniform();
    memcpy(x,ip->x,3*sizeof(double));
    memcpy(v,ip->v,3*sizeof(double));
    Particle::OnePart *particles = particle->particles;
    int reallocflag =
      particle->add_particle(pid,adsorbed,ip->icell,x,v,0.0,0.0);
    if (reallocflag) ip = particle->particles + (ip - particles);
    jp = &particle->particles[particle->nlocal-1];

    diffuse->wrapper(ip,norm,NULL,diffuse_coeffs);
    diffuse->wrapper(jp,norm,NULL,diffuse_coeffs);
    velreset = 1;
    return 0;
  }

  nsingle++;
  tally_single[ireaction]++;

  // tally-only candidates do not execute chemistry
  // outer surf collision still performs its configured scattering/heat tally

  if (tally_only_flag) {
    if (only_one_flag) MPI_Win_unlock(one_owner,one_state_win);
    return 0;
  }

  if (only_one_flag) {
    put_one_state(one_owner,one_disp,0);
    MPI_Win_unlock(one_owner,one_state_win);
  } else {
    mark_surface(isurf);
    species_delta[isurf][jsurf]--;
  }

  ip->ispecies = rlist[ireaction].product;
  diffuse->wrapper(ip,norm,NULL,diffuse_coeffs);
  velreset = 1;

  return ireaction + 1;
}

/* ---------------------------------------------------------------------- */

char *SurfReactGamma::reactionID(int m)
{
  return rlist[m].id;
}

/* ---------------------------------------------------------------------- */

double SurfReactGamma::reaction_coeff(int m)
{
  if (m < 0 || m >= nlist) return 0.0;
  return rlist[m].reaction_energy;
}

/* ---------------------------------------------------------------------- */

const char *SurfReactGamma::gs_model()
{
  return (const char *) "constant-gamma";
}

/* ---------------------------------------------------------------------- */

int SurfReactGamma::match_reactant(char *species, int m)
{
  if (strcmp(species,rlist[m].id_reactants[0]) == 0) return 1;
  if (strcmp(species,rlist[m].id_reactants[1]) == 0) return 1;
  return 0;
}

/* ---------------------------------------------------------------------- */

int SurfReactGamma::match_product(char *species, int m)
{
  return strcmp(species,rlist[m].id_product) == 0;
}

/* ---------------------------------------------------------------------- */

void SurfReactGamma::tally_update()
{
  SurfReact::tally_update();

  // No PS clock is used.  Commit gas/surface state changes every timestep.

  if (only_one_flag) sync_one_state();
  else if (mode == FACE) update_state_face();
  else update_state_surf();
}

/* ----------------------------------------------------------------------
   called when grid adaptation changes local+ghost distributed surfs
------------------------------------------------------------------------- */

void SurfReactGamma::grid_changed()
{
  if (mode == FACE || !distributed) return;

  memory->destroy(surf_species_delta);
  int nall = surf->nlocal + surf->nghost;
  memory->create(surf_species_delta,nall,nspecies_surf,
                 "react/gamma:surf_species_delta");
  if (nall)
    memset(&surf_species_delta[0][0],0,
           nall*nspecies_surf*sizeof(int));
  species_delta = surf_species_delta;

  memory->destroy(mark);
  memory->create(mark,nall,"react/gamma:mark");
  if (nall) memset(mark,0,nall*sizeof(int));

  memory->destroy(outcollate);
  memory->create(outcollate,surf->nown,nspecies_surf,
                 "react/gamma:outcollate");

  surf->spread_custom(total_state_index);
  surf->spread_custom(species_state_index);
  surf->spread_custom(area_index);
  surf->spread_custom(weight_index);

  total_state = surf->edvec_local[surf->ewhich[total_state_index]];
  species_state = surf->edarray_local[surf->ewhich[species_state_index]];
  area = surf->edvec_local[surf->ewhich[area_index]];
  weight = surf->edvec_local[surf->ewhich[weight_index]];

  surf->assign_unique();
}

/* ----------------------------------------------------------------------
   create the globally unique one-site state
   value = 0 for vacant, gas species index + 1 for occupied
   explicit surface ownership follows Surf::collate_*():
     owner = (surf ID - 1) % nprocs
     displacement = (surf ID - 1) / nprocs
------------------------------------------------------------------------- */

void SurfReactGamma::create_one_state_window()
{
  if (mode == FACE) {
    one_state_nown = nface/nprocs;
    if (me < nface % nprocs) one_state_nown++;
  } else one_state_nown = surf->nown;

  MPI_Aint nbytes = (MPI_Aint) one_state_nown * sizeof(int);
  MPI_Win_allocate(nbytes,sizeof(int),MPI_INFO_NULL,world,
                   &one_state_owned,&one_state_win);

  // Initialize through a legal passive-target RMA epoch.  MPI_Win_sync()
  // cannot be called outside an epoch, and strict multi-node OSC backends
  // report MPI_ERR_RMA_SYNC for that usage.

  if (one_state_nown) {
    int *zero = new int[one_state_nown];
    memset(zero,0,one_state_nown*sizeof(int));
    MPI_Win_lock(MPI_LOCK_EXCLUSIVE,me,0,one_state_win);
    MPI_Put(zero,one_state_nown,MPI_INT,
            me,0,one_state_nown,MPI_INT,one_state_win);
    MPI_Win_unlock(me,one_state_win);
    delete [] zero;
  }
  MPI_Barrier(world);
}

/* ----------------------------------------------------------------------
   map a local collision surface to its unique state owner and displacement
------------------------------------------------------------------------- */

void SurfReactGamma::one_state_location(int isurf, int &owner,
                                         MPI_Aint &disp)
{
  surfint id;
  if (mode == FACE) {
    int iface = isurf;
    if (iface < 0 || iface >= nface)
      error->one(FLERR,"Invalid surf_react gamma box face");
    id = iface + 1;
  } else {
    if (isurf < 0 || isurf >= surf->nlocal+surf->nghost)
      error->one(FLERR,"Invalid surf_react gamma surface index");
    if (domain->dimension == 2) id = surf->lines[isurf].id;
    else id = surf->tris[isurf].id;
  }

  if (id < 1 || (mode == SURF && id > surf->nsurf))
    error->one(FLERR,"Invalid surf_react gamma surface ID");

  owner = (int) ((id-1) % nprocs);
  disp = (MPI_Aint) ((id-1) / nprocs);
}

/* ----------------------------------------------------------------------
   acquire exclusive access and return the encoded one-site state
   caller must update if needed and unlock the returned owner
------------------------------------------------------------------------- */

int SurfReactGamma::lock_one_state(int isurf, int &owner, MPI_Aint &disp)
{
  one_state_location(isurf,owner,disp);

  int encoded = 0;
  MPI_Win_lock(MPI_LOCK_EXCLUSIVE,owner,0,one_state_win);
  MPI_Get(&encoded,1,MPI_INT,owner,disp,1,MPI_INT,one_state_win);
  MPI_Win_flush(owner,one_state_win);
  return encoded;
}

/* ---------------------------------------------------------------------- */

void SurfReactGamma::put_one_state(int owner, MPI_Aint disp, int encoded)
{
  MPI_Put(&encoded,1,MPI_INT,owner,disp,1,MPI_INT,one_state_win);
  MPI_Win_flush(owner,one_state_win);
}

/* ----------------------------------------------------------------------
   mirror the unique owner state into the existing output arrays
   all collision locks have been released before tally_update() is called
------------------------------------------------------------------------- */

void SurfReactGamma::sync_one_state()
{
  MPI_Barrier(world);

  // Fetch through the window, including for the local target.  This is valid
  // for both MPI's unified and separate public/private memory models.

  int *snapshot = NULL;
  if (one_state_nown) {
    snapshot = new int[one_state_nown];
    MPI_Win_lock(MPI_LOCK_SHARED,me,0,one_state_win);
    MPI_Get(snapshot,one_state_nown,MPI_INT,me,0,one_state_nown,MPI_INT,
            one_state_win);
    MPI_Win_unlock(me,one_state_win);
  }

  if (mode == FACE) {
    int *one = new int[nface];
    int *all = new int[nface];
    for (int i = 0; i < nface; i++) one[i] = 0;
    for (int iface = me, i = 0; iface < nface; iface += nprocs, i++)
      one[iface] = snapshot[i];

    MPI_Allreduce(one,all,nface,MPI_INT,MPI_SUM,world);

    for (int iface = 0; iface < nface; iface++) {
      face_total_state[iface] = all[iface] ? 1.0 : 0.0;
      for (int j = 0; j < nspecies_surf; j++)
        face_species_state[iface][j] = 0.0;
      if (all[iface]) {
        if (all[iface] < 1 || all[iface] > particle->nspecies)
          error->all(FLERR,"Invalid surf_react gamma one-site species");
        int jsurf = species2surf[all[iface]-1];
        if (jsurf < 0)
          error->all(FLERR,"Invalid surf_react gamma one-site species");
        face_species_state[iface][jsurf] = 1.0;
      }
    }

    delete [] one;
    delete [] all;
    delete [] snapshot;
    return;
  }

  double *owned_total = surf->edvec[surf->ewhich[total_state_index]];
  double **owned_species =
    surf->edarray[surf->ewhich[species_state_index]];

  for (int i = 0; i < surf->nown; i++) {
    int encoded = snapshot[i];
    owned_total[i] = encoded ? 1.0 : 0.0;
    for (int j = 0; j < nspecies_surf; j++) owned_species[i][j] = 0.0;
    if (encoded) {
      if (encoded < 1 || encoded > particle->nspecies)
        error->all(FLERR,"Invalid surf_react gamma one-site species");
      int jsurf = species2surf[encoded-1];
      if (jsurf < 0)
        error->all(FLERR,"Invalid surf_react gamma one-site species");
      owned_species[i][jsurf] = 1.0;
    }
  }

  surf->spread_custom(total_state_index);
  surf->spread_custom(species_state_index);

  total_state = surf->edvec_local[surf->ewhich[total_state_index]];
  species_state = surf->edarray_local[surf->ewhich[species_state_index]];
  delete [] snapshot;
}

/* ----------------------------------------------------------------------
   read and parse the constant-gamma reaction file
------------------------------------------------------------------------- */

void SurfReactGamma::readfile(char *fname)
{
  int eof,n1,n2;
  char line1[MAXLINE],line2[MAXLINE];
  char copy1[MAXLINE],copy2[MAXLINE];

  if (me == 0) {
    fp = fopen(fname,"r");
    if (fp == NULL) {
      char str[128];
      sprintf(str,"Cannot open reaction file %s",fname);
      error->one(FLERR,str);
    }
  }

  while (1) {
    if (me == 0) eof = readone(line1,line2,n1,n2);
    MPI_Bcast(&eof,1,MPI_INT,0,world);
    if (eof == 1) break;
    if (eof < 0)
      error->all(FLERR,"Missing reaction heat in surf_react gamma file");

    MPI_Bcast(&n1,1,MPI_INT,0,world);
    MPI_Bcast(&n2,1,MPI_INT,0,world);
    MPI_Bcast(line1,n1,MPI_CHAR,0,world);
    MPI_Bcast(line2,n2,MPI_CHAR,0,world);

    strcpy(copy1,line1);
    strcpy(copy2,line2);

    char *words[6];
    int nwords = 0;
    char *word = strtok(line1," \t\r\n");
    while (word && nwords < 6) {
      words[nwords++] = word;
      word = strtok(NULL," \t\r\n");
    }

    if (nwords != 5 || word ||
        strcmp(words[1],"+") != 0 || strcmp(words[3],"-->") != 0) {
      print_reaction(copy1,copy2);
      error->all(FLERR,"Invalid surf_react gamma reaction formula");
    }

    int reactant0 = particle->find_species(words[0]);
    int reactant1 = particle->find_species(words[2]);
    int product = particle->find_species(words[4]);
    if (reactant0 < 0 || reactant1 < 0 || product < 0) {
      print_reaction(copy1,copy2);
      error->all(FLERR,"Surf_react gamma species is not defined");
    }

    word = strtok(line2," \t\r\n");
    if (!word) {
      print_reaction(copy1,copy2);
      error->all(FLERR,"Invalid surf_react gamma reaction heat");
    }
    double reaction_energy = input->numeric(FLERR,word);
    if (strtok(NULL," \t\r\n")) {
      print_reaction(copy1,copy2);
      error->all(FLERR,"Too many values in surf_react gamma reaction heat");
    }

    for (int i = 0; i < nlist; i++) {
      int a0 = rlist[i].reactants[0];
      int a1 = rlist[i].reactants[1];
      if ((a0 == reactant0 && a1 == reactant1) ||
          (a0 == reactant1 && a1 == reactant0)) {
        print_reaction(copy1,copy2);
        error->all(FLERR,"Duplicate unordered surf_react gamma reaction");
      }
    }

    if (nlist == maxlist) {
      maxlist += DELTALIST;
      rlist = (OneReaction *)
        memory->srealloc(rlist,maxlist*sizeof(OneReaction),
                         "surf_react/gamma:rlist");
    }

    OneReaction *r = &rlist[nlist];
    int n = strlen(copy1) + 1;
    r->id = new char[n];
    strcpy(r->id,copy1);

    n = strlen(words[0]) + 1;
    r->id_reactants[0] = new char[n];
    strcpy(r->id_reactants[0],words[0]);
    n = strlen(words[2]) + 1;
    r->id_reactants[1] = new char[n];
    strcpy(r->id_reactants[1],words[2]);
    n = strlen(words[4]) + 1;
    r->id_product = new char[n];
    strcpy(r->id_product,words[4]);

    r->reactants[0] = reactant0;
    r->reactants[1] = reactant1;
    r->product = product;
    r->reaction_energy = reaction_energy;
    nlist++;
  }

  if (me == 0) fclose(fp);
}

/* ----------------------------------------------------------------------
   read two effective lines, skipping blank and comment lines for both
------------------------------------------------------------------------- */

int SurfReactGamma::readone(char *line1, char *line2, int &n1, int &n2)
{
  if (read_effective_line(line1,n1)) return 1;
  if (read_effective_line(line2,n2)) return -1;
  return 0;
}

/* ---------------------------------------------------------------------- */

int SurfReactGamma::read_effective_line(char *line, int &n)
{
  while (fgets(line,MAXLINE,fp)) {
    char *comment = strchr(line,'#');
    if (comment) *comment = '\0';

    int first = strspn(line," \t\r\n");
    int length = strlen(line);
    if (first == length) continue;

    if (first) memmove(line,line+first,length-first+1);
    length = strlen(line);
    while (length &&
           (line[length-1] == ' ' || line[length-1] == '\t' ||
            line[length-1] == '\r' || line[length-1] == '\n'))
      line[--length] = '\0';
    if (length == 0) continue;

    n = length + 1;
    return 0;
  }

  return 1;
}

/* ---------------------------------------------------------------------- */

void SurfReactGamma::print_reaction(char *line1, char *line2)
{
  if (me) return;
  printf("Bad gamma reaction format:\n");
  printf("%s\n%s\n",line1,line2);
}

/* ---------------------------------------------------------------------- */

void SurfReactGamma::build_surface_species()
{
  int nspecies = particle->nspecies;
  int *flag = new int[nspecies];
  for (int i = 0; i < nspecies; i++) flag[i] = gamma_set[i];

  for (int i = 0; i < ninitial; i++) flag[initial[i].species] = 1;
  for (int i = 0; i < nlist; i++) {
    flag[rlist[i].reactants[0]] = 1;
    flag[rlist[i].reactants[1]] = 1;
  }

  nspecies_surf = 0;
  for (int i = 0; i < nspecies; i++)
    if (flag[i]) nspecies_surf++;

  species_surf = new int[nspecies_surf];
  species2surf = new int[nspecies];
  for (int i = 0; i < nspecies; i++) species2surf[i] = -1;

  int n = 0;
  for (int i = 0; i < nspecies; i++)
    if (flag[i]) {
      species_surf[n] = i;
      species2surf[i] = n++;
    }

  delete [] flag;
}

/* ---------------------------------------------------------------------- */

void SurfReactGamma::build_reaction_map()
{
  int nspecies = particle->nspecies;
  memory->create(reaction_map,nspecies,nspecies,
                 "surf_react/gamma:reaction_map");
  for (int i = 0; i < nspecies; i++)
    for (int j = 0; j < nspecies; j++)
      reaction_map[i][j] = -1;

  for (int i = 0; i < nlist; i++) {
    int a = rlist[i].reactants[0];
    int b = rlist[i].reactants[1];
    reaction_map[a][b] = reaction_map[b][a] = i;
  }
}

/* ---------------------------------------------------------------------- */

void SurfReactGamma::create_per_face_state()
{
  nface = 2 * domain->dimension;
  memory->create(face_species_state,nface,nspecies_surf,
                 "react/gamma:face_species_state");
  memory->create(face_total_state,nface,"react/gamma:face_total_state");
  memory->create(face_area,nface,"react/gamma:face_area");
  memory->create(face_weight,nface,"react/gamma:face_weight");
  memory->create(face_species_delta,nface,nspecies_surf,
                 "react/gamma:face_species_delta");
  memory->create(face_sum_delta,nface,nspecies_surf,
                 "react/gamma:face_sum_delta");

  for (int iface = 0; iface < nface; iface++) {
    face_total_state[iface] = 0.0;
    for (int isp = 0; isp < nspecies_surf; isp++) {
      face_species_state[iface][isp] = 0.0;
      face_species_delta[iface][isp] = 0;
    }

    if (domain->dimension == 2) {
      if (iface < 2) face_area[iface] = domain->prd[1];
      else face_area[iface] = domain->prd[0];
    } else {
      if (iface < 2) face_area[iface] = domain->prd[1]*domain->prd[2];
      else if (iface < 4) face_area[iface] = domain->prd[0]*domain->prd[2];
      else face_area[iface] = domain->prd[0]*domain->prd[1];
    }
    face_weight[iface] = 1.0;
  }

  species_state = face_species_state;
  total_state = face_total_state;
  area = face_area;
  weight = face_weight;
  species_delta = face_species_delta;
}

/* ---------------------------------------------------------------------- */

void SurfReactGamma::create_per_surf_state()
{
  total_state_index = surf->find_custom(total_state_name);
  species_state_index = surf->find_custom(species_state_name);
  area_index = surf->find_custom(area_name);
  weight_index = surf->find_custom(weight_name);

  int nfound = 0;
  if (total_state_index >= 0) nfound++;
  if (species_state_index >= 0) nfound++;
  if (area_index >= 0) nfound++;
  if (weight_index >= 0) nfound++;

  if (nfound == 0) {
    total_state_index = surf->add_custom(total_state_name,DOUBLE,0);
    species_state_index =
      surf->add_custom(species_state_name,DOUBLE,nspecies_surf);
    area_index = surf->add_custom(area_name,DOUBLE,0);
    weight_index = surf->add_custom(weight_name,DOUBLE,0);
  } else if (nfound != 4) {
    error->all(FLERR,"Surf_react gamma custom attribute(s) already exist");
  } else {
    if (surf->etype[total_state_index] != DOUBLE ||
        surf->esize[total_state_index] != 0 ||
        surf->etype[species_state_index] != DOUBLE ||
        surf->esize[species_state_index] != nspecies_surf ||
        surf->etype[area_index] != DOUBLE || surf->esize[area_index] != 0 ||
        surf->etype[weight_index] != DOUBLE || surf->esize[weight_index] != 0)
      error->all(FLERR,"Invalid surf_react gamma custom attribute");
  }

  int nall = surf->nlocal + surf->nghost;
  memory->create(surf_species_delta,nall,nspecies_surf,
                 "react/gamma:surf_species_delta");
  if (nall)
    memset(&surf_species_delta[0][0],0,
           nall*nspecies_surf*sizeof(int));
  species_delta = surf_species_delta;

  memory->create(mark,nall,"react/gamma:mark");
  if (nall) memset(mark,0,nall*sizeof(int));

  memory->create(outcollate,surf->nown,nspecies_surf,
                 "react/gamma:outcollate");
}

/* ---------------------------------------------------------------------- */

void SurfReactGamma::initialize_per_surf_state()
{
  Surf::Line *lines = surf->lines;
  Surf::Tri *tris = surf->tris;
  Surf::Line *mylines = surf->mylines;
  Surf::Tri *mytris = surf->mytris;

  double *owned_area = surf->edvec[surf->ewhich[area_index]];
  double *owned_weight = surf->edvec[surf->ewhich[weight_index]];

  if (!distributed) {
    for (int i = 0; i < surf->nown; i++) {
      int ilocal = me + i*nprocs;
      if (ilocal >= surf->nlocal || !assigned_to_this(ilocal)) continue;
      if (domain->dimension == 2)
        owned_area[i] = surf->line_size(&lines[ilocal]);
      else {
        double tmp;
        owned_area[i] = surf->tri_size(&tris[ilocal],tmp);
      }
      owned_weight[i] = 1.0;
    }

  } else {
    for (int i = 0; i < surf->nown; i++) {
      int isr;
      if (domain->dimension == 2) isr = mylines[i].isr;
      else isr = mytris[i].isr;
      if (isr < 0 || surf->sr[isr] != this) continue;

      if (domain->dimension == 2)
        owned_area[i] = surf->line_size(&mylines[i]);
      else {
        double tmp;
        owned_area[i] = surf->tri_size(&mytris[i],tmp);
      }
      owned_weight[i] = 1.0;
    }
  }

  initialize_cover_surf();

  surf->spread_custom(total_state_index);
  surf->spread_custom(species_state_index);
  surf->spread_custom(area_index);
  surf->spread_custom(weight_index);

  total_state = surf->edvec_local[surf->ewhich[total_state_index]];
  species_state = surf->edarray_local[surf->ewhich[species_state_index]];
  area = surf->edvec_local[surf->ewhich[area_index]];
  weight = surf->edvec_local[surf->ewhich[weight_index]];

  if (distributed) surf->assign_unique();
}

/* ---------------------------------------------------------------------- */

void SurfReactGamma::initialize_cover_face()
{
  for (int iface = 0; iface < nface; iface++) {
    long int capacity = max_sites(iface);
    long int used = 0;
    for (int i = 0; i < ninitial; i++) {
      int jsurf = species2surf[initial[i].species];
      long int count = (long int)
        floor(capacity*initial[i].fraction + 0.5);
      if (used + count > capacity) count = capacity-used;
      species_state[iface][jsurf] = count;
      used += count;
    }
    total_state[iface] = used;
  }
}

/* ---------------------------------------------------------------------- */

void SurfReactGamma::initialize_cover_surf()
{
  double *owned_total = surf->edvec[surf->ewhich[total_state_index]];
  double **owned_species =
    surf->edarray[surf->ewhich[species_state_index]];
  double *owned_area = surf->edvec[surf->ewhich[area_index]];
  double *owned_weight = surf->edvec[surf->ewhich[weight_index]];

  Surf::Line *mylines = surf->mylines;
  Surf::Tri *mytris = surf->mytris;

  for (int i = 0; i < surf->nown; i++) {
    int assigned;
    if (!distributed) {
      int ilocal = me + i*nprocs;
      assigned = ilocal < surf->nlocal && assigned_to_this(ilocal);
    } else {
      int isr;
      if (domain->dimension == 2) isr = mylines[i].isr;
      else isr = mytris[i].isr;
      assigned = isr >= 0 && surf->sr[isr] == this;
    }
    if (!assigned) continue;

    long int capacity = (long int)
      ceil(nsite*owned_area[i]/(update->fnum*owned_weight[i]));
    long int used = 0;
    for (int j = 0; j < ninitial; j++) {
      int jsurf = species2surf[initial[j].species];
      long int count = (long int)
        floor(capacity*initial[j].fraction + 0.5);
      if (used + count > capacity) count = capacity-used;
      owned_species[i][jsurf] = count;
      used += count;
    }
    owned_total[i] = used;
  }
}

/* ---------------------------------------------------------------------- */

void SurfReactGamma::update_state_face()
{
  MPI_Allreduce(&species_delta[0][0],&face_sum_delta[0][0],
                nface*nspecies_surf,MPI_INT,MPI_SUM,world);

  for (int i = 0; i < nface; i++) {
    long int total = 0;
    for (int j = 0; j < nspecies_surf; j++) {
      double value = species_state[i][j] + face_sum_delta[i][j];
      if (value < -0.5)
        error->all(FLERR,"Surf_react gamma surface count became negative");
      if (value < 0.0) value = 0.0;
      species_state[i][j] = value;
      total += (long int) value;
      species_delta[i][j] = 0;
    }
    if (total > max_sites(i))
      error->all(FLERR,"Surf_react gamma surface capacity exceeded");
    total_state[i] = total;
  }
}

/* ---------------------------------------------------------------------- */

void SurfReactGamma::update_state_surf()
{
  Surf::Line *lines = surf->lines;
  Surf::Tri *tris = surf->tris;
  int nall = surf->nlocal + surf->nghost;
  int ntally = 0;

  for (int i = 0; i < nall; i++) {
    if (!mark[i]) continue;
    mark[i] = 0;

    int isr;
    if (domain->dimension == 2) isr = lines[i].isr;
    else isr = tris[i].isr;
    if (isr < 0 || surf->sr[isr] != this) continue;

    if (ntally == maxtally) {
      maxtally += DELTA_TALLY;
      memory->grow(tally2surf,maxtally,"react/gamma:tally2surf");
      memory->grow(incollate,maxtally,nspecies_surf,
                   "react/gamma:incollate");
    }

    if (domain->dimension == 2) tally2surf[ntally] = lines[i].id;
    else tally2surf[ntally] = tris[i].id;
    for (int j = 0; j < nspecies_surf; j++) {
      incollate[ntally][j] = species_delta[i][j];
      species_delta[i][j] = 0;
    }
    ntally++;
  }

  surf->collate_array(ntally,nspecies_surf,tally2surf,
                      incollate,outcollate);

  total_state = surf->edvec[surf->ewhich[total_state_index]];
  species_state = surf->edarray[surf->ewhich[species_state_index]];
  area = surf->edvec[surf->ewhich[area_index]];
  weight = surf->edvec[surf->ewhich[weight_index]];

  for (int i = 0; i < surf->nown; i++) {
    long int total = 0;
    for (int j = 0; j < nspecies_surf; j++) {
      double value = species_state[i][j] + outcollate[i][j];
      if (value < -0.5)
        error->all(FLERR,"Surf_react gamma surface count became negative");
      if (value < 0.0) value = 0.0;
      species_state[i][j] = value;
      total += (long int) value;
    }
    if (area[i] > 0.0 && total > max_sites(i))
      error->all(FLERR,"Surf_react gamma surface capacity exceeded");
    total_state[i] = total;
  }

  surf->spread_custom(total_state_index);
  surf->spread_custom(species_state_index);

  total_state = surf->edvec_local[surf->ewhich[total_state_index]];
  species_state = surf->edarray_local[surf->ewhich[species_state_index]];
  area = surf->edvec_local[surf->ewhich[area_index]];
  weight = surf->edvec_local[surf->ewhich[weight_index]];
}

/* ---------------------------------------------------------------------- */

int SurfReactGamma::assigned_to_this(int isurf)
{
  int isr;
  if (domain->dimension == 2) isr = surf->lines[isurf].isr;
  else isr = surf->tris[isurf].isr;
  return isr >= 0 && surf->sr[isr] == this;
}

/* ---------------------------------------------------------------------- */

long int SurfReactGamma::max_sites(int isurf)
{
  if (only_one_flag) return 1;
  return (long int) ceil(nsite*area[isurf] /
                         (update->fnum*weight[isurf]));
}

/* ---------------------------------------------------------------------- */

int SurfReactGamma::effective_count(int isurf, int jsurf)
{
  double value = species_state[isurf][jsurf] +
    species_delta[isurf][jsurf];
  if (value <= 0.0) return 0;
  return (int) value;
}

/* ----------------------------------------------------------------------
   return surface-species index, or -1 for a vacant site
------------------------------------------------------------------------- */

int SurfReactGamma::select_surface_species(int isurf)
{
  long int capacity = max_sites(isurf);
  long int total = 0;
  for (int j = 0; j < nspecies_surf; j++)
    total += effective_count(isurf,j);

  if (total > capacity)
    error->one(FLERR,"Surf_react gamma local surface capacity exceeded");

  long int site = (long int) (random->uniform()*capacity);
  if (site >= total) return -1;

  long int cumulative = 0;
  for (int j = 0; j < nspecies_surf; j++) {
    cumulative += effective_count(isurf,j);
    if (site < cumulative) return j;
  }

  return -1;
}

/* ---------------------------------------------------------------------- */

void SurfReactGamma::mark_surface(int isurf)
{
  if (mode == SURF) mark[isurf] = 1;
}

/* ---------------------------------------------------------------------- */

char *SurfReactGamma::custom_name(const char *suffix)
{
  int n = strlen(id) + strlen(suffix) + 8;
  char *name = new char[n];
  sprintf(name,"gamma_%s_%s",id,suffix);
  return name;
}
